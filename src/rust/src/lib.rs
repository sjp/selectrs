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
    let message = error.into_message(selector);
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
