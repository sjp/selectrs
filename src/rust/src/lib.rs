mod parser;
mod translate;

use savvy::savvy;
use savvy::{OwnedStringSexp, StringSexp};

use translate::Translator;

/// Version of the selectrs Rust core
///
/// Returns the version of the underlying Rust crate. A trivial export used
/// to verify that the Rust toolchain and FFI bindings are working.
///
/// @returns A length-one character vector.
/// @noRd
#[savvy]
fn selectrs_core_version() -> savvy::Result<savvy::Sexp> {
    let mut out = OwnedStringSexp::new(1)?;
    out.set_elt(0, env!("CARGO_PKG_VERSION"))?;
    Ok(out.into())
}

/// Translate CSS selectors to XPath expressions
///
/// The vectorized core of `css_to_xpath()`. R has already validated and
/// recycled the arguments to equal length. The first element that fails —
/// invalid syntax or an unsupported construct — aborts the call with an
/// error naming the selector and the construct, matching selectr's
/// mid-iteration throw.
///
/// @param selectors A character vector of CSS selectors.
/// @param prefixes A character vector of XPath prefixes.
/// @param translators A character vector: "generic", "html", or "xhtml".
/// @returns A character vector of XPath expressions.
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

    let prefixes: Vec<&str> = prefixes.iter().collect();
    let translators: Vec<&str> = translators.iter().collect();

    let mut out = OwnedStringSexp::new(n)?;
    for (i, selector) in selectors.iter().enumerate() {
        let translator = Translator::new(translators[i])
            .ok_or_else(|| savvy::Error::new(format!("Unknown translator '{}'", translators[i])))?;
        match translator.css_to_xpath(selector, prefixes[i]) {
            Ok(xpath) => out.set_elt(i, &xpath)?,
            Err(e) => return Err(savvy::Error::new(e.into_message(selector))),
        }
    }
    Ok(out.into())
}

#[cfg(test)]
mod tests {
    use crate::translate::Translator;

    fn xpath(css: &str) -> String {
        Translator::new("generic")
            .unwrap()
            .css_to_xpath(css, "")
            .unwrap()
    }

    /// Expectations harvested verbatim from selectr's test-translation.R
    /// (simple-selector portion) and spot-checks against selectr at
    /// sjp/selectr@717e2ee.
    #[test]
    fn simple_selectors() {
        assert_eq!(xpath("*"), "*");
        assert_eq!(xpath("e"), "e");
        assert_eq!(xpath("*|e"), "*[(local-name() = 'e')]");
        assert_eq!(xpath("|e"), "e");
        assert_eq!(xpath("|*"), "*[(namespace-uri() = '')]");
        assert_eq!(xpath("*|*"), "*");
        assert_eq!(xpath("e|f"), "e:f");
        assert_eq!(xpath("svg|*"), "svg:*");
        assert_eq!(xpath("e[foo]"), "e[(@foo)]");
        assert_eq!(xpath("e[foo|bar]"), "e[(@foo:bar)]");
        assert_eq!(xpath("[*|foo]"), "*[(@*[local-name() = 'foo'])]");
        assert_eq!(xpath("[|foo]"), "*[(@foo)]");
        assert_eq!(xpath("e[foo=\"bar\"]"), "e[(@foo = 'bar')]");
        assert_eq!(xpath("e[foo=\"\"]"), "e[(@foo = '')]");
        assert_eq!(
            xpath("e[foo|=\"\"]"),
            "e[(@foo and (@foo = '' or starts-with(@foo, '-')))]"
        );
        assert_eq!(
            xpath("e[foo~=\"bar\"]"),
            "e[(@foo and contains(concat(' ', normalize-space(@foo), ' '), ' bar '))]"
        );
        assert_eq!(
            xpath("e[foo^=\"bar\"]"),
            "e[(@foo and starts-with(@foo, 'bar'))]"
        );
        assert_eq!(
            xpath("e[foo$=\"bar\"]"),
            "e[(@foo and substring(@foo, string-length(@foo)-2) = 'bar')]"
        );
        assert_eq!(
            xpath("e[foo*=\"bar\"]"),
            "e[(@foo and contains(@foo, 'bar'))]"
        );
        assert_eq!(
            xpath("e[hreflang|=\"en\"]"),
            "e[(@hreflang and (@hreflang = 'en' or starts-with(@hreflang, 'en-')))]"
        );
    }

    #[test]
    fn class_id_combinators() {
        assert_eq!(
            xpath("e.warning"),
            "e[(@class and contains(concat(' ', normalize-space(@class), ' '), ' warning '))]"
        );
        assert_eq!(xpath("e#myid"), "e[(@id = 'myid')]");
        assert_eq!(xpath("e f"), "e//f");
        assert_eq!(xpath("e > f"), "e/f");
        assert_eq!(xpath("e + f"), "e/following-sibling::*[1][self::f]");
        assert_eq!(xpath("e ~ f"), "e/following-sibling::f");
        assert_eq!(
            xpath("e + f[bar]"),
            "e/following-sibling::*[1][self::f][(@bar)]"
        );
        assert_eq!(xpath("e + *"), "e/following-sibling::*[1][self::*]");
        assert_eq!(xpath("div#container p"), "div[(@id = 'container')]//p");
        assert_eq!(xpath("a , b"), "a | b");
    }

    #[test]
    fn unsafe_names_and_escapes() {
        assert_eq!(xpath("di\\[v"), "*[(name() = 'di[v')]");
        assert_eq!(xpath("[h\\]ref]"), "*[(attribute::*[name() = 'h]ref'])]");
        assert_eq!(xpath("di\u{a0}v"), "*[(name() = 'di\u{a0}v')]");
        // Unicode escapes are decoded to the characters they represent,
        // in idents, hashes, and strings alike (sjp/selectr@717e2ee).
        assert_eq!(xpath("#\\31 23"), "*[(@id = '123')]");
        assert_eq!(xpath("\\31 23"), "*[(name() = '123')]");
        assert_eq!(xpath("[\\31 23]"), "*[(attribute::*[name() = '123'])]");
        assert_eq!(xpath("e[foo='\\31 23']"), "e[(@foo = '123')]");
        assert_eq!(xpath("e[foo='x\\79 z']"), "e[(@foo = 'xyz')]");
        // '*|' bypasses the safe-name fallback: quoting handles it.
        assert_eq!(xpath("*|di\\[v"), "*[(local-name() = 'di[v')]");
        assert_eq!(xpath("[*|h\\]ref]"), "*[(@*[local-name() = 'h]ref'])]");
    }

    #[test]
    fn case_sensitivity_flags() {
        const LOWER_FOO: &str = "translate(@foo, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', \
                                 'abcdefghijklmnopqrstuvwxyz')";
        assert_eq!(
            xpath("e[foo=\"Bar\" i]"),
            format!("e[({LOWER_FOO} = 'bar')]")
        );
        // Flag idents are themselves case-insensitive.
        assert_eq!(
            xpath("e[foo=\"Bar\" I]"),
            format!("e[({LOWER_FOO} = 'bar')]")
        );
        assert_eq!(
            xpath("e[foo^=\"Bar\" i]"),
            format!("e[({LOWER_FOO} and starts-with({LOWER_FOO}, 'bar'))]")
        );
        assert_eq!(
            xpath("e[foo$=\"Bar\" i]"),
            format!(
                "e[({LOWER_FOO} and substring({LOWER_FOO}, \
                 string-length({LOWER_FOO})-2) = 'bar')]"
            )
        );
        // ASCII-only lowering: non-ASCII characters are left alone.
        assert_eq!(
            xpath("e[foo=\"B\u{e4}r\" i]"),
            format!("e[({LOWER_FOO} = 'b\u{e4}r')]")
        );
        // An empty value keeps the exact translation.
        assert_eq!(xpath("e[foo=\"\" i]"), "e[(@foo = '')]");
        // 's' requests the default case-sensitive matching.
        assert_eq!(xpath("e[foo=\"Bar\" s]"), "e[(@foo = 'Bar')]");
        // The flag composes with namespaced attribute forms.
        assert_eq!(
            xpath("e[*|foo=\"Bar\" i]"),
            format!(
                "e[(translate(@*[local-name() = 'foo'], \
                 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', \
                 'abcdefghijklmnopqrstuvwxyz') = 'bar')]"
            )
        );
    }

    #[test]
    fn unsupported_errors() {
        let t = Translator::new("generic").unwrap();
        assert!(t.css_to_xpath("e[foo!=\"bar\"]", "").is_err());
        assert!(t.css_to_xpath("e:hover", "").is_err()); // Phase 2
        assert!(t.css_to_xpath("e::before", "").is_err());
        assert!(t.css_to_xpath("e:", "").is_err());
        assert!(t.css_to_xpath("", "").is_err());
        // A flag requires an operator and value.
        assert!(t.css_to_xpath("[rel i]", "").is_err());
        assert!(t.css_to_xpath("[rel=stylesheet k]", "").is_err());
        assert!(t.css_to_xpath("[rel=stylesheet i i]", "").is_err());
    }

    #[test]
    fn html_translator_lowercases_names_not_values() {
        let html = Translator::new("html").unwrap();
        assert_eq!(html.css_to_xpath("DIV", "").unwrap(), "div");
        assert_eq!(html.css_to_xpath("[FOO]", "").unwrap(), "*[(@foo)]");
        // Names lowercase, values keep their case (sjp/selectr@930cb87).
        assert_eq!(
            html.css_to_xpath("DIV[Value=\"Mixed Case\"]", "").unwrap(),
            "div[(@value = 'Mixed Case')]"
        );
        // The element inside local-name() is lowercased too.
        assert_eq!(
            html.css_to_xpath("*|DIV", "").unwrap(),
            "*[(local-name() = 'div')]"
        );
        // xhtml preserves case
        let xhtml = Translator::new("xhtml").unwrap();
        assert_eq!(xhtml.css_to_xpath("DIV", "").unwrap(), "DIV");
    }

    #[test]
    fn prefix_applied_per_branch() {
        let t = Translator::new("generic").unwrap();
        assert_eq!(
            t.css_to_xpath("a, b", "descendant-or-self::").unwrap(),
            "descendant-or-self::a | descendant-or-self::b"
        );
    }
}
