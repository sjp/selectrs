use std::collections::HashMap;

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
    out.set_elt(0, css_to_xpath::VERSION)?;
    Ok(out.into())
}

/// Longest selector, in bytes, echoed whole in an error message.
///
/// R truncates a printed error at `options(warning.length)`, 1000 bytes
/// by default. The caret line that locates the error comes last, so it
/// is the first thing lost when a message is built around a selector
/// long enough to overrun that budget. Two echoes of this many bytes,
/// plus the rest of the message, stay inside it.
const ECHO_LIMIT: usize = 200;

/// Characters of context kept either side of the caret once a selector
/// is too long to echo whole.
const WINDOW_RADIUS: usize = 30;

/// Longest failure detail kept, in bytes. Both the parse detail and the
/// unsupported construct quote the offending token back, so a selector
/// carrying a 5 KB identifier otherwise produces a 5 KB detail. The
/// condition fields keep the untruncated text.
const DETAIL_LIMIT: usize = 120;

/// Byte offset of the `n`th character of `s`, or `s.len()` if it is shorter.
fn byte_of_char(s: &str, n: usize) -> usize {
    s.char_indices()
        .nth(n)
        .map_or(s.len(), |(offset, _)| offset)
}

/// Shorten `s` to `limit` bytes, marking the cut with an ellipsis.
fn elide(s: &str, limit: usize) -> String {
    if s.len() <= limit {
        return s.to_string();
    }
    let mut end = limit;
    while !s.is_char_boundary(end) {
        end -= 1;
    }
    format!("{}…", &s[..end])
}

/// Character index the parser's `column` points at within `selector`.
///
/// The column is 1-based and counted in UTF-16 code units, the position
/// the underlying CSS parser reports; a caret has to be placed by
/// character instead, or it lands off the mark in any selector holding
/// non-ASCII text.
fn char_index_of_column(selector: &str, column: u32) -> usize {
    let target = (column as usize).saturating_sub(1);
    let mut units = 0;
    for (index, character) in selector.chars().enumerate() {
        if units >= target {
            return index;
        }
        units += character.len_utf16();
    }
    selector.chars().count()
}

/// Point at `column` within `selector`.
///
/// A selector too long to echo whole is reduced to a window around the
/// column, with an ellipsis on each side that was cut.
fn caret_block(selector: &str, column: u32) -> String {
    let total = selector.chars().count();
    let caret = char_index_of_column(selector, column).min(total);

    let (start, end) = if selector.len() <= ECHO_LIMIT {
        (0, total)
    } else {
        (
            caret.saturating_sub(WINDOW_RADIUS),
            caret.saturating_add(WINDOW_RADIUS).min(total),
        )
    };

    let mut echo = String::new();
    if start > 0 {
        echo.push('…');
    }
    echo.push_str(&selector[byte_of_char(selector, start)..byte_of_char(selector, end)]);
    if end < total {
        echo.push('…');
    }

    let pad = " ".repeat(caret - start + usize::from(start > 0));
    format!("  |\n  | {echo}\n  | {pad}^")
}

/// Say where the selector the message could not show in full is kept.
fn full_selector_note(selector: &str) -> String {
    format!(
        "  = the whole {}-character selector is the condition's `selector` field",
        selector.chars().count()
    )
}

/// Render the user-facing message for a failed translation.
///
/// Short selectors are quoted in full, as `css_to_xpath::Error` itself
/// renders them. A selector past `ECHO_LIMIT` is abbreviated instead of
/// echoed twice, so that what locates the failure survives R's cap on
/// the length of a printed error message.
fn render_message(error: &Error, selector: &str) -> String {
    let short = selector.len() <= ECHO_LIMIT;
    match error {
        Error::Parse(detail, column) => {
            let detail = elide(detail, DETAIL_LIMIT);
            let caret = caret_block(selector, *column);
            if short {
                format!("Unable to parse the CSS selector {selector:?}: {detail}\n{caret}")
            } else {
                format!(
                    "Unable to parse the CSS selector at column {column}: {detail}\n{caret}\n{}",
                    full_selector_note(selector)
                )
            }
        }
        Error::Unsupported(construct) => {
            let construct = elide(construct, DETAIL_LIMIT);
            if short {
                format!(
                    "The CSS selector {selector:?} uses {construct}, which this translator does not support"
                )
            } else {
                format!(
                    "The CSS selector uses {construct}, which this translator does not support\n{}",
                    full_selector_note(selector)
                )
            }
        }
    }
}

/// Describe a failed translation for R.
///
/// The named list holds the kind of failure, its rendered message, the
/// offending selector and its 1-based position in the vectorized call,
/// plus the field particular to the kind: the error `column` for a parse
/// failure, the `construct` for an unsupported one.
fn describe_failure(error: Error, selector: &str, index: usize) -> savvy::Result<savvy::Sexp> {
    let mut out = OwnedListSexp::new(5, true)?;
    // Set from within the match so the value is installed in the (already
    // protected) list rather than held as a bare SEXP across allocations.
    let kind = match &error {
        Error::Parse(_, column) => {
            out.set_name_and_value(4, "column", OwnedIntegerSexp::try_from(*column as i32)?)?;
            "parse"
        }
        Error::Unsupported(construct) => {
            out.set_name_and_value(
                4,
                "construct",
                OwnedStringSexp::try_from(construct.as_str())?,
            )?;
            "unsupported"
        }
    };
    out.set_name_and_value(0, "kind", OwnedStringSexp::try_from(kind)?)?;
    let message = render_message(&error, selector);
    out.set_name_and_value(1, "message", OwnedStringSexp::try_from(message)?)?;
    out.set_name_and_value(2, "selector", OwnedStringSexp::try_from(selector)?)?;
    out.set_name_and_value(3, "index", OwnedIntegerSexp::try_from(index as i32)?)?;
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
    let translators: Vec<Translator> = translator_names
        .iter()
        .map(|name| {
            if name.is_na() {
                return Err(savvy::Error::new(
                    "`translators` must not contain NA values",
                ));
            }
            let mode = match *name {
                "generic" => Mode::Generic,
                "html" => Mode::Html,
                "xhtml" => Mode::Xhtml,
                other => return Err(savvy::Error::new(format!("Unknown translator '{other}'"))),
            };
            Ok(Translator::new(mode))
        })
        .collect::<Result<_, _>>()?;

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
        match translators[i].css_to_xpath(selector, prefixes[i]) {
            Ok(xpath) => {
                out.set_elt(i, &xpath)?;
                cache.insert(key, xpath);
            }
            Err(e) => return describe_failure(e, selector, i + 1),
        }
    }
    Ok(out.into())
}
