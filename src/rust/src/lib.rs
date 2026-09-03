use std::collections::HashMap;
use std::str::FromStr;

use savvy::savvy;
use savvy::{NotAvailableValue, OwnedIntegerSexp, OwnedListSexp, OwnedStringSexp, StringSexp};

use css_to_xpath::{Error, Mode, Translator};

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
/// is mirrored here; should the two drift, the note is added a little
/// early or late and nothing else changes.
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

/// Describe a failed translation for R.
///
/// The named list holds the kind of failure, its rendered message, the
/// offending selector and its 1-based position in the vectorized call,
/// plus whatever else the error knows: the `construct` an unsupported
/// selector names, and the `column` it failed at. A parse failure always
/// has a position; an unsupported construct only has one when the crate
/// found it lexically, so the list is sized by what is actually there
/// and a caller reads an absent field as `NULL` either way.
fn describe_failure(error: Error, selector: &str, index: usize) -> savvy::Result<savvy::Sexp> {
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

    let extra = usize::from(construct.is_some()) + usize::from(offset.is_some());
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
