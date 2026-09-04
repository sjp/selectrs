use std::collections::HashMap;
use std::fmt::Write;
use std::str::FromStr;

use savvy::savvy;
use savvy::{
    NotAvailableValue, OwnedIntegerSexp, OwnedListSexp, OwnedLogicalSexp, OwnedStringSexp,
    StringSexp,
};

use css_to_xpath::{Error, Mode, ParseErrorKind, Translator};

/// Version of the css-to-xpath translation crate
///
/// Returns the version of the underlying `css-to-xpath` crate. A trivial
/// export used to verify that the Rust toolchain and FFI bindings are
/// working.
///
/// @returns A length-one character vector.
/// @noRd
#[savvy]
fn selectrs_core_version() -> savvy::Result<savvy::Sexp> {
    let mut out = OwnedStringSexp::new(1)?;
    out.set_elt(0, env!("CSS_TO_XPATH_VERSION"))?;
    Ok(out.into())
}

/// Panic, so that the unwind path can be tested from R
///
/// The whole input surface is arbitrary user CSS flowing into
/// third-party parsing code, so the release profile sets
/// `panic = "unwind"` to keep a reachable panic a catchable R error
/// rather than a dead session. Nothing else reaches that path on
/// purpose, so this export exists for the test that does. It is not in
/// NAMESPACE and takes no arguments; the only way to call it is by name
/// from inside the package.
///
/// @returns Never returns.
/// @noRd
#[savvy]
fn selectrs_panic_test() -> savvy::Result<savvy::Sexp> {
    panic!("panic from the Rust core")
}

/// Longest selector, in bytes, that `css_to_xpath::Error::message()`
/// quotes in full. Past it the message shows the caret window rather
/// than the whole selector, so the condition's own copy is worth
/// pointing at. The crate keeps this threshold to itself, so the value
/// is mirrored here and a test holds the mirror against the messages the
/// crate actually renders; should the crate move its threshold, that
/// test fails rather than the note being added a little early or late.
const CRATE_SELECTOR_ECHO: usize = 120;

/// 1-based character column for the crate's 0-indexed byte offset.
///
/// The crate reports a position as a byte offset, and R counts in
/// characters; the two only agree while the selector is ASCII. An offset
/// at end of input gives the column one past the last character.
fn column_of_offset(selector: &str, offset: usize) -> i32 {
    let characters = selector
        .char_indices()
        .take_while(|(index, _)| *index < offset)
        .count();
    (characters + 1) as i32
}

/// Render the user-facing message for a failed translation.
///
/// The crate renders it, caret gutter and all, bounding every part: the
/// quoted selector, the token a parse failure echoes, and the width of
/// the gutter, so that a selector of many kilobytes still yields a few
/// hundred bytes. That matters because R truncates a printed error at
/// `options(warning.length)`, and the caret line, coming last, is the
/// first thing a longer message would lose. All that is added here is a
/// pointer to the condition's `selector` field, for a selector too long
/// to have been quoted whole.
fn render_message(error: &Error, selector: &str) -> String {
    let message = error.message(selector);
    if selector.len() <= CRATE_SELECTOR_ECHO {
        message
    } else {
        format!(
            "{message}\n  = the whole {}-character selector is the condition's `selector` field",
            selector.chars().count()
        )
    }
}

/// The pseudo-elements CSS 2.1 lets a single colon spell. selectr names
/// all four with two colons however they were written, so `a:before` and
/// `a::before` both give the feature `::before`.
const LEGACY_PSEUDO_ELEMENTS: [&str; 4] = ["before", "after", "first-line", "first-letter"];

/// The constructs this translator rejects that selectr's grammar has no
/// production for at all, and so reports as parse errors. Matched by the
/// crate's own wording, which its documentation makes part of its output
/// contract; `pseudo_written_as()` covers the traffic in the other
/// direction.
const OUTSIDE_SELECTR_GRAMMAR: [&str; 2] =
    ["the `||` column combinator", "the `&` nesting selector"];

/// A pseudo-class or pseudo-element as it stands in the selector text.
struct WrittenPseudo {
    /// Byte offset of the colon that introduces it — the first of two,
    /// when it was written with two.
    offset: usize,
    /// Written `::`, or spelled with the single colon CSS 2.1 allows one
    /// of its four pseudo-elements.
    element: bool,
    /// Followed by an argument list.
    functional: bool,
    /// selectr's name for it: `::before`, `:frobnicate`, `:lang()`.
    token: String,
}

/// Find where the pseudo-class or pseudo-element `name` was written.
///
/// The crate reports the bare name, without the colons that introduced
/// it or the argument list that followed, because its parser cannot tell
/// how many colons were written. Both are needed to name the construct
/// the way selectr does, so they are read back off the source text: the
/// colon run is the last one at or before `limit`, which is the offset
/// the crate reported. A selector that writes the name twice
/// (`[x=":before"] p:before`) is what makes the bound worth having;
/// searching the whole string is only the fallback for an offset that
/// lands before the construct.
fn pseudo_written_as(selector: &str, name: &str, limit: usize) -> Option<WrittenPseudo> {
    let follows = |offset: usize| {
        let tail = selector.get(offset + 1..)?;
        if !tail.get(..name.len())?.eq_ignore_ascii_case(name) {
            return None;
        }
        // A longer name starting with this one is a different pseudo:
        // `:lang` must not match the `:language` written before it.
        let next = tail[name.len()..].chars().next();
        match next {
            Some(c) if c == '-' || c == '_' || c == '\\' || c.is_alphanumeric() => None,
            _ => Some(next),
        }
    };

    let (mut at_or_before, mut after) = (None, None);
    for (offset, _) in selector.match_indices(':') {
        let Some(next) = follows(offset) else {
            continue;
        };
        if offset <= limit {
            at_or_before = Some((offset, next));
        } else if after.is_none() {
            after = Some((offset, next));
        }
    }
    let (offset, next) = at_or_before.or(after)?;

    let lower = name.to_ascii_lowercase();
    let doubled = selector[..offset].ends_with(':');
    let element = doubled || LEGACY_PSEUDO_ELEMENTS.contains(&lower.as_str());
    let functional = next == Some('(');
    let token = if element {
        format!("::{lower}")
    } else if functional {
        format!(":{lower}()")
    } else {
        format!(":{lower}")
    };
    Some(WrittenPseudo {
        offset: if doubled { offset - 1 } else { offset },
        element,
        functional,
        token,
    })
}

/// selectr's short name for an unsupported construct, where it has one.
///
/// selectr's `feature` field is a token a handler can switch on —
/// `":scope"`, `":lang()"` — where this crate's `construct` is the noun
/// phrase its message reads as. A construct selectr has no counterpart
/// for, such as a nesting limit or an unquotable namespace prefix, has
/// no token, and the condition falls back to the phrase.
fn selectr_feature(construct: &str, selector: &str) -> Option<String> {
    // Both `:scope` phrases — outside the leftmost compound, and inside a
    // functional pseudo-class — are one feature to selectr.
    if construct.contains("`:scope`") {
        return Some(":scope".to_owned());
    }
    // Only ever reached from `:host(`: bare `:host` is a parse failure,
    // which the boundary rewrite turns into `:host` instead.
    if construct == "the `:host` pseudo-class" {
        return Some(":host()".to_owned());
    }
    if construct.starts_with("the :lang() language range") {
        return Some(":lang()".to_owned());
    }
    if construct == "`:only-of-type` on the universal selector `*`" {
        return Some("*:only-of-type".to_owned());
    }
    if construct != "an of-type pseudo-class on the universal selector `*`" {
        return None;
    }
    // The one phrase that is less specific than selectr's token, which
    // names the pseudo-class it was: read it back off the selector from
    // the start, taking the leftmost, that being the one a left-to-right
    // translation reaches first. The universal selector may be implicit,
    // so the token is written with the `*` selectr writes either way.
    [
        "first-of-type",
        "last-of-type",
        "nth-of-type",
        "nth-last-of-type",
    ]
    .iter()
    .filter_map(|name| pseudo_written_as(selector, name, 0))
    .min_by_key(|pseudo| pseudo.offset)
    .map(|pseudo| format!("*{}", pseudo.token))
}

/// Restate a failure where selectr draws the parse/translation line, and
/// name its construct the way selectr names it.
///
/// selectr's parser accepts any `:name` and leaves an unknown or
/// unsupported one to its translator, so what this crate reports as a
/// malformed selector is a translation failure there — except for a
/// *functional* pseudo-element (`::slotted(x)`), which selectr's parser
/// rejects as well. Its grammar has no `||` or `&` at all, so those two
/// go the other way. The error is rebuilt rather than merely
/// reclassified, so the message a caller prints still agrees with the
/// class the condition carries.
fn at_selectr_boundary(error: Error, selector: &str) -> (Error, Option<String>) {
    match error {
        Error::Parse {
            kind: ParseErrorKind::UnsupportedPseudo(name),
            offset,
        } => match pseudo_written_as(selector, &name, offset) {
            Some(pseudo) if !(pseudo.element && pseudo.functional) => {
                let noun = if pseudo.element { "element" } else { "class" };
                let construct = format!("the `{}` pseudo-{noun}", pseudo.token);
                let error = Error::Unsupported {
                    construct,
                    offset: Some(pseudo.offset),
                };
                (error, Some(pseudo.token))
            }
            _ => (
                Error::Parse {
                    kind: ParseErrorKind::UnsupportedPseudo(name),
                    offset,
                },
                None,
            ),
        },
        Error::Unsupported {
            construct,
            offset: Some(offset),
        } if OUTSIDE_SELECTR_GRAMMAR.contains(&construct.as_str()) => {
            let kind = ParseErrorKind::Other(format!("{construct} is not supported"));
            (Error::Parse { kind, offset }, None)
        }
        Error::Unsupported { construct, offset } => {
            let feature = selectr_feature(&construct, selector);
            (Error::Unsupported { construct, offset }, feature)
        }
        other => (other, None),
    }
}

/// Describe a failed translation for R.
///
/// The named list holds the kind of failure, its rendered message, the
/// offending selector and its 1-based position in the vectorized call,
/// plus whatever else the error knows: the `construct` an unsupported
/// selector names, selectr's `feature` token for it where there is one,
/// and the `column` it failed at. A parse failure always has a position;
/// an unsupported construct only has one when the crate found it
/// lexically, so the list is sized by what is actually there and a
/// caller reads an absent field as `NULL` either way.
fn describe_failure(error: Error, selector: &str, index: usize) -> savvy::Result<savvy::Sexp> {
    let (error, feature) = at_selectr_boundary(error, selector);
    let (kind, construct, offset) = match &error {
        Error::Parse { offset, .. } => ("parse", None, Some(*offset)),
        Error::Unsupported { construct, offset } => {
            ("unsupported", Some(construct.to_string()), *offset)
        }
        // `Error` is non-exhaustive, so a variant the crate adds has to
        // reach R as an ordinary failure rather than a panic. Its
        // `Display` names the construct, which is what the field holds.
        other => ("unsupported", Some(other.to_string()), None),
    };

    let extra = usize::from(construct.is_some())
        + usize::from(feature.is_some())
        + usize::from(offset.is_some());
    let mut out = OwnedListSexp::new(4 + extra, true)?;
    out.set_name_and_value(0, "kind", OwnedStringSexp::try_from(kind)?)?;
    let message = render_message(&error, selector);
    out.set_name_and_value(1, "message", OwnedStringSexp::try_from(message)?)?;
    out.set_name_and_value(2, "selector", OwnedStringSexp::try_from(selector)?)?;
    out.set_name_and_value(3, "index", OwnedIntegerSexp::try_from(index as i32)?)?;
    let mut slot = 4;
    if let Some(construct) = construct {
        out.set_name_and_value(slot, "construct", OwnedStringSexp::try_from(construct)?)?;
        slot += 1;
    }
    if let Some(feature) = feature {
        out.set_name_and_value(slot, "feature", OwnedStringSexp::try_from(feature)?)?;
        slot += 1;
    }
    if let Some(offset) = offset {
        let column = column_of_offset(selector, offset);
        out.set_name_and_value(slot, "column", OwnedIntegerSexp::try_from(column)?)?;
    }
    Ok(out.into())
}

/// Translate CSS selectors to XPath expressions
///
/// The vectorized core of `css_to_xpath()`. R has already validated and
/// recycled the arguments to equal length.
///
/// A selector that fails to translate does not raise an error here: the
/// first failure is returned as the named list `describe_failure()`
/// builds, so that R can raise a condition classed by the kind of
/// failure. Success returns a character vector, so the caller tells the
/// two apart by type.
///
/// @param selectors A character vector of CSS selectors.
/// @param prefixes A character vector of XPath prefixes.
/// @param translators A character vector: "generic", "html", or "xhtml".
/// @returns A character vector of XPath expressions, or a named list
///   describing the first selector that could not be translated.
/// @noRd
#[savvy]
fn css_to_xpath_rust(
    selectors: StringSexp,
    prefixes: StringSexp,
    translators: StringSexp,
) -> savvy::Result<savvy::Sexp> {
    let n = selectors.len();
    if prefixes.len() != n || translators.len() != n {
        return Err(savvy::Error::new(
            "`selectors`, `prefixes`, and `translators` must have equal lengths",
        ));
    }

    // R validates too, but anything reaching this boundary directly
    // would otherwise translate NA as the literal element `NA`.
    let prefixes: Vec<&str> = prefixes.iter().collect();
    if prefixes.iter().any(|p| p.is_na()) {
        return Err(savvy::Error::new("`prefixes` must not contain NA values"));
    }
    let translator_names: Vec<&str> = translators.iter().collect();
    // However long the input, it names at most three translators.
    let mut translators: HashMap<&str, Translator> = HashMap::new();
    for name in &translator_names {
        if name.is_na() {
            return Err(savvy::Error::new(
                "`translators` must not contain NA values",
            ));
        }
        if translators.contains_key(name) {
            continue;
        }
        let Ok(mode) = Mode::from_str(name) else {
            return Err(savvy::Error::new(format!("Unknown translator '{name}'")));
        };
        translators.insert(*name, Translator::new(mode));
    }

    let mut out = OwnedStringSexp::new(n)?;
    // Duplicated (selector, prefix, translator) triples are translated
    // once and the result reused.
    let mut cache: HashMap<(&str, &str, &str), String> = HashMap::new();
    for (i, selector) in selectors.iter().enumerate() {
        if selector.is_na() {
            return Err(savvy::Error::new("`selectors` must not contain NA values"));
        }
        let key = (selector, prefixes[i], translator_names[i]);
        if let Some(xpath) = cache.get(&key) {
            out.set_elt(i, xpath)?;
            continue;
        }
        match translators[&translator_names[i]].css_to_xpath(selector, prefixes[i]) {
            Ok(xpath) => {
                out.set_elt(i, &xpath)?;
                cache.insert(key, xpath);
            }
            Err(e) => return describe_failure(e, selector, i + 1),
        }
    }
    Ok(out.into())
}

/// Whether `prefix` can be written into an XPath expression as a
/// namespace prefix, which is to say whether it is an XML `NCName`.
///
/// The crate asks this of every prefix written in a selector but keeps
/// the predicate to itself, so it is put to the translator instead,
/// which is the one way it is exported: the prefix is translated as the
/// selector `<prefix>|a`, whose only way to fail is that test.
///
/// The escaping is what makes the answer the crate's own. A prefix
/// written literally would be read as selector syntax — `*` as the
/// universal namespace, a space as a descendant combinator, a leading
/// digit as a malformed selector — and answer a different question,
/// whereas the parser rebuilds an escaped name exactly as given.
fn is_ncname(prefix: &str) -> bool {
    // Nothing to escape leaves `|a`, the selector for `a` in no
    // namespace at all, which translates happily.
    if prefix.is_empty() {
        return false;
    }
    let mut selector = String::with_capacity(prefix.len() * 4 + 2);
    for c in prefix.chars() {
        // A hex escape runs to the first character that cannot continue
        // it, so each one ends in the space that the parser consumes:
        // without it `\61 b` would be the single escape `\61b`.
        let _ = write!(selector, "\\{:x} ", c as u32);
    }
    selector.push_str("|a");
    Translator::new(Mode::Generic)
        .css_to_xpath(&selector, "")
        .is_ok()
}

/// Which namespace prefixes can be written into an XPath expression
///
/// The R layer splices the names of the `ns` map into the XPath it
/// builds around a translated selector, where a name that is not an XML
/// name comes back from libxml2 as a syntax error over an expression
/// the caller never wrote. Asking the core decides an `ns` name by the
/// same rule as a prefix written in a selector, so `svg|rect` and
/// `ns = c(svg = ...)` cannot disagree about what a prefix may be.
///
/// @param prefixes A character vector of namespace prefixes.
/// @returns A logical vector, one element per prefix.
/// @noRd
#[savvy]
fn valid_ns_prefixes_rust(prefixes: StringSexp) -> savvy::Result<savvy::Sexp> {
    let mut out = OwnedLogicalSexp::new(prefixes.len())?;
    for (i, prefix) in prefixes.iter().enumerate() {
        if prefix.is_na() {
            return Err(savvy::Error::new("`prefixes` must not contain NA values"));
        }
        out.set_elt(i, is_ncname(prefix))?;
    }
    Ok(out.into())
}

/// The build script's lock-file reader, compiled in for its tests only:
/// cargo runs no tests in a build script.
#[cfg(test)]
mod locked_version;

#[cfg(test)]
mod tests {
    use super::*;

    /// The error a selector that cannot be translated fails with.
    fn failure(selector: &str) -> Error {
        Translator::new(Mode::Generic)
            .css_to_xpath(selector, "")
            .expect_err("the selector should not translate")
    }

    /// A selector of exactly `bytes` bytes that fails to parse: `pad`
    /// repeated to length, then a dangling child combinator.
    fn padded(pad: &str, bytes: usize) -> String {
        let selector = format!("{} >", pad.repeat((bytes - 2) / pad.len()));
        assert_eq!(selector.len(), bytes, "the padding does not divide evenly");
        selector
    }

    #[test]
    fn column_of_offset_counts_from_one() {
        assert_eq!(column_of_offset("div > p", 0), 1);
        assert_eq!(column_of_offset("div > p", 4), 5);
    }

    #[test]
    fn column_of_offset_counts_characters_not_bytes() {
        // Each of the three leading characters is two bytes wide, so the
        // sixth byte is the fourth character.
        assert_eq!(column_of_offset("äöü > p", 6), 4);
    }

    #[test]
    fn column_of_offset_is_one_past_the_end_at_end_of_input() {
        // The offset the crate reports for an error at end of input.
        assert_eq!(column_of_offset("div >", 5), 6);
        assert_eq!(column_of_offset("äöü >", 9), 6);
    }

    #[test]
    fn column_of_offset_is_total() {
        // Neither an offset past the end nor one landing inside a
        // character can come from the crate; both must still answer.
        assert_eq!(column_of_offset("div", 99), 4);
        assert_eq!(column_of_offset("", 0), 1);
        assert_eq!(column_of_offset("äöü", 1), 2);
    }

    #[test]
    fn crate_selector_echo_is_where_the_crate_stops_quoting() {
        // The mirrored threshold, checked against the only thing the
        // crate exposes of it: whether a message quotes the selector
        // whole. At the threshold it does, one byte over it does not.
        let quoted = |selector: &str| {
            let message = failure(selector).message(selector);
            message.contains(&format!("{selector:?}"))
        };
        assert!(
            quoted(&padded("a", CRATE_SELECTOR_ECHO)),
            "the crate elides below {CRATE_SELECTOR_ECHO} bytes"
        );
        assert!(
            !quoted(&padded("a", CRATE_SELECTOR_ECHO + 1)),
            "the crate still quotes whole past {CRATE_SELECTOR_ECHO} bytes"
        );
    }

    /// How `describe_failure()` would class the failure, and the feature
    /// it would carry: what the boundary rewrite decides, read back off
    /// the error it produces.
    fn classify(selector: &str) -> (&'static str, Option<String>) {
        let (error, feature) = at_selectr_boundary(failure(selector), selector);
        let kind = match error {
            Error::Parse { .. } => "parse",
            _ => "unsupported",
        };
        (kind, feature)
    }

    /// The feature `classify()` found, for the cases that must have one.
    fn feature(selector: &str) -> String {
        classify(selector)
            .1
            .expect("the failure should name a feature")
    }

    #[test]
    fn an_unsupported_pseudo_is_a_translation_failure() {
        // selectr parses any `:name` and rejects an unknown or
        // unsupported one while translating, so these are on its
        // translation side however this crate's parser reads them.
        for selector in [
            "e:frobnicate",
            "a:first_child",
            "a::before",
            "a:contains(x)",
            ":nth-col(2n)",
            ":host",
            "input:indeterminate",
            "a:lang(1)",
        ] {
            assert_eq!(classify(selector).0, "unsupported", "{selector}");
        }
    }

    #[test]
    fn a_functional_pseudo_element_stays_a_parse_failure() {
        // The one shape selectr's parser rejects too: `::name(` is not
        // in its grammar, whichever colon count spelled the name.
        for selector in ["::slotted(x)", "a::part(b)", "a:before(x)"] {
            assert_eq!(classify(selector), ("parse", None), "{selector}");
        }
    }

    #[test]
    fn the_two_constructs_selectr_cannot_parse_are_parse_failures() {
        for selector in ["col || td", "& a"] {
            assert_eq!(classify(selector), ("parse", None), "{selector}");
        }
    }

    #[test]
    fn a_rewritten_failure_reads_as_the_kind_it_is_now() {
        // The message has to follow the class, or a caller printing one
        // is told the opposite of what the condition says.
        let (error, _) = at_selectr_boundary(failure("e:frobnicate"), "e:frobnicate");
        assert_eq!(
            error.message("e:frobnicate"),
            "The CSS selector \"e:frobnicate\" uses the `:frobnicate` pseudo-class, \
             which this translator does not support\n  |\n  | e:frobnicate\n  |  ^"
        );
        let (error, _) = at_selectr_boundary(failure("col || td"), "col || td");
        assert!(
            error.message("col || td").starts_with(
                "Unable to parse the CSS selector \"col || td\": \
                              the `||` column combinator is not supported"
            ),
            "{}",
            error.message("col || td")
        );
    }

    #[test]
    fn the_feature_is_the_token_selectr_names_the_construct_with() {
        assert_eq!(feature("e:frobnicate"), ":frobnicate");
        assert_eq!(feature("a:contains(x)"), ":contains()");
        assert_eq!(feature(":host"), ":host");
        assert_eq!(feature(":host(x)"), ":host()");
        assert_eq!(feature("a > :scope"), ":scope");
        assert_eq!(feature(":is(:scope)"), ":scope");
        assert_eq!(feature(":lang(*-CH)"), ":lang()");
        assert_eq!(feature("a:lang(1)"), ":lang()");
        assert_eq!(feature("*:only-of-type"), "*:only-of-type");
        // The crate's phrase names no one pseudo-class here, so the token
        // is read back off the selector.
        assert_eq!(feature("*:first-of-type"), "*:first-of-type");
        assert_eq!(feature("*:nth-last-of-type(2)"), "*:nth-last-of-type()");
        assert_eq!(feature(":first-of-type"), "*:first-of-type");
        // A construct selectr has no token for keeps the phrase, which
        // the R layer copies into `feature` instead.
        assert_eq!(
            classify(&format!("{}a{}", ":not(".repeat(33), ")".repeat(33))).1,
            None
        );
    }

    #[test]
    fn a_pseudo_element_is_named_with_two_colons_however_it_was_written() {
        // CSS 2.1 lets these four take one colon; selectr reports both
        // spellings the same way, and lower-cases the name.
        assert_eq!(feature("a:before"), "::before");
        assert_eq!(feature("a::BEFORE"), "::before");
        assert_eq!(feature("a:AFTER"), "::after");
        assert_eq!(feature("p::first-letter"), "::first-letter");
        // An unknown name spelled with two colons is a pseudo-element to
        // selectr as well, because two colons is what makes one.
        assert_eq!(feature("a::nosuch"), "::nosuch");
        assert_eq!(feature("a:nosuch"), ":nosuch");
    }

    #[test]
    fn a_pseudo_is_located_at_the_colon_that_introduces_it() {
        // The caret points at the construct, not wherever the parse
        // happened to stop, which for a functional pseudo is its
        // argument list.
        let located = |selector: &str| match at_selectr_boundary(failure(selector), selector).0 {
            Error::Unsupported { offset, .. } => offset,
            other => panic!("{selector} should be unsupported, got {other:?}"),
        };
        assert_eq!(located("a::before"), Some(1));
        assert_eq!(located("a:before"), Some(1));
        assert_eq!(located("a:contains(x)"), Some(1));
        assert_eq!(located("input:indeterminate"), Some(5));
    }

    #[test]
    fn a_pseudo_written_twice_is_read_at_the_reported_offset() {
        // The name also stands inside a string, which the search must
        // not settle on: the bound is the offset the crate reported.
        let selector = "[x=\":before\"] p::before";
        assert_eq!(feature(selector), "::before");
        let pseudo = pseudo_written_as(selector, "before", 16).expect("written twice");
        assert_eq!(pseudo.offset, 15);
        assert!(pseudo.element);
    }

    #[test]
    fn a_name_another_name_starts_with_is_not_the_pseudo() {
        // `:lang` must not be found in the `:language` that precedes it.
        let selector = ":language(x) :lang(1)";
        let pseudo = pseudo_written_as(selector, "lang", 19).expect("the second one");
        assert_eq!(pseudo.offset, 13);
        assert!(pseudo.functional);
    }

    #[test]
    fn a_pseudo_that_cannot_be_found_leaves_the_failure_alone() {
        // The crate elides a name past 40 bytes, so a long enough one no
        // longer matches the text and the parse error stands as it is.
        let selector = format!("a:{}", "n".repeat(60));
        assert_eq!(classify(&selector), ("parse", None));
    }

    #[test]
    fn render_message_leaves_a_quoted_selector_alone() {
        let selector = "div >";
        let error = failure(selector);
        assert_eq!(render_message(&error, selector), error.message(selector));
    }

    #[test]
    fn render_message_adds_no_note_at_the_echo_threshold() {
        let selector = padded("a", CRATE_SELECTOR_ECHO);
        let error = failure(&selector);
        assert_eq!(render_message(&error, &selector), error.message(&selector));
    }

    #[test]
    fn render_message_notes_the_selector_field_past_the_threshold() {
        let selector = padded("a", CRATE_SELECTOR_ECHO + 1);
        let error = failure(&selector);
        let message = render_message(&error, &selector);
        assert_eq!(
            message.strip_prefix(&error.message(&selector)),
            Some("\n  = the whole 121-character selector is the condition's `selector` field")
        );
    }

    #[test]
    fn render_message_counts_the_note_in_characters() {
        // Three bytes to the character: over the byte threshold the note
        // applies, and the count it reports is not that of bytes.
        let selector = padded("日", CRATE_SELECTOR_ECHO + 5);
        assert_eq!(selector.chars().count(), 43);
        let error = failure(&selector);
        assert!(
            render_message(&error, &selector).ends_with(
                "\n  = the whole 43-character selector is the condition's `selector` field"
            ),
            "the note should report characters, not the {} bytes",
            selector.len()
        );
    }

    #[test]
    fn ascii_prefixes_are_names_on_the_same_terms_as_xml() {
        assert!(is_ncname("svg"));
        assert!(is_ncname("_x"));
        assert!(is_ncname("x.y-z"));
        assert!(!is_ncname(""));
        assert!(!is_ncname("1a"));
        assert!(!is_ncname("-a"));
        assert!(!is_ncname("x:y"));
        assert!(!is_ncname("a/b"));
    }

    #[test]
    fn a_prefix_is_judged_as_written_not_as_selector_syntax() {
        // Each of these means something else when it is parsed as a
        // selector rather than as one escaped name: `*|a` is the
        // universal namespace, `a b|a` a descendant combinator.
        assert!(!is_ncname("*"));
        assert!(!is_ncname("a b"));
        assert!(!is_ncname("|"));
        assert!(!is_ncname("a\\b"));
    }

    #[test]
    fn non_ascii_prefixes_follow_the_xml_1_0_tables() {
        assert!(is_ncname("\u{e9}l"));
        assert!(is_ncname("\u{65e5}\u{672c}"));
        // U+00B7 MIDDLE DOT and the combining marks may follow the
        // first character of a name but cannot be it.
        assert!(is_ncname("a\u{b7}b"));
        assert!(!is_ncname("\u{b7}a"));
        assert!(is_ncname("a\u{300}"));
        assert!(!is_ncname("\u{300}a"));
        // U+00AA is a letter to Unicode but not to XML 1.0, and this is
        // the row the check exists for: libxml2 refuses it, so an `ns`
        // name that reached the query would fail there instead.
        assert!(!is_ncname("\u{aa}"));
    }
}
