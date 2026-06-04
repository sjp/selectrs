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
/// error naming the selector and the construct.
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

    /// Type, namespace, and attribute selector forms.
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
        // in idents, hashes, and strings alike.
        assert_eq!(xpath("#\\31 23"), "*[(@id = '123')]");
        assert_eq!(xpath("\\31 23"), "*[(name() = '123')]");
        assert_eq!(xpath("[\\31 23]"), "*[(attribute::*[name() = '123'])]");
        assert_eq!(xpath("e[foo='\\31 23']"), "e[(@foo = '123')]");
        assert_eq!(xpath("e[foo='x\\79 z']"), "e[(@foo = 'xyz')]");
        // '*|' bypasses the safe-name fallback: quoting handles it.
        assert_eq!(xpath("*|di\\[v"), "*[(local-name() = 'di[v')]");
        assert_eq!(xpath("[*|h\\]ref]"), "*[(@*[local-name() = 'h]ref'])]");
        // '|' with a name needing quoting keeps the no-namespace
        // constraint alongside the name() test.
        assert_eq!(
            xpath("|di\\[v"),
            "*[(name() = 'di[v') and (namespace-uri() = '')]"
        );
        assert_eq!(xpath("|é"), "*[(name() = 'é') and (namespace-uri() = '')]");
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
        // The non-standard [a!=b] and :contains() are not supported.
        assert!(t.css_to_xpath("e[foo!=\"bar\"]", "").is_err());
        assert!(t.css_to_xpath("e:contains(\"foo\")", "").is_err());
        assert!(t.css_to_xpath("e::before", "").is_err());
        assert!(t.css_to_xpath("e:", "").is_err());
        assert!(t.css_to_xpath("", "").is_err());
        // A flag requires an operator and value.
        assert!(t.css_to_xpath("[rel i]", "").is_err());
        assert!(t.css_to_xpath("[rel=stylesheet k]", "").is_err());
        assert!(t.css_to_xpath("[rel=stylesheet i i]", "").is_err());
        // Unknown pseudo-classes error.
        assert!(t.css_to_xpath("e:scope", "").is_err());
        assert!(t.css_to_xpath("e:first-line", "").is_err()); // pseudo-element
        // The pseudo-class argument grammar: one compound per argument
        // (after :has()'s optional leading combinator).
        assert!(t.css_to_xpath("e:is(a b)", "").is_err());
        assert!(t.css_to_xpath("e:is(> a)", "").is_err()); // :has()-only
        assert!(t.css_to_xpath("e:has(a > b)", "").is_err());
        assert!(t.css_to_xpath("e:has(> > a)", "").is_err());
        assert!(t.css_to_xpath("e:has(>)", "").is_err());
        assert!(t.css_to_xpath("e:has(a >)", "").is_err());
        // Nested :has() is rejected (selectors-4).
        assert!(t.css_to_xpath("e:has(a:has(b))", "").is_err());
        assert!(t.css_to_xpath("e:has(> a:has(b))", "").is_err());
        // of-type pseudos on `*` are not implemented.
        assert!(t.css_to_xpath("*:first-of-type", "").is_err());
        assert!(t.css_to_xpath("*:nth-last-of-type(2)", "").is_err());
        // :lang()/:dir() argument validation; a lone '-' is not a valid
        // ident.
        assert!(t.css_to_xpath(":lang()", "").is_err());
        assert!(t.css_to_xpath(":lang(5)", "").is_err());
        assert!(t.css_to_xpath(":lang(-)", "").is_err());
        // An+B must be whitespace-exact and integer-valued.
        assert!(t.css_to_xpath("e:nth-child(3 7)", "").is_err());
        assert!(t.css_to_xpath("e:nth-child(2 n)", "").is_err());
        assert!(t.css_to_xpath("e:nth-child(2.5)", "").is_err());
        assert!(t.css_to_xpath("e:nth-child(2e1)", "").is_err());
    }

    /// The nth-* family and its an+b arithmetic.
    #[test]
    fn nth_family() {
        assert_eq!(
            xpath("e:nth-child(1)"),
            "e[(count(preceding-sibling::*) = 0)]"
        );
        assert_eq!(
            xpath("e:nth-child(3n+2)"),
            "e[(count(preceding-sibling::*) >= 1 and (count(preceding-sibling::*) +2) mod 3 = 0)]"
        );
        assert_eq!(
            xpath("e:nth-child(3n-2)"),
            "e[(count(preceding-sibling::*) mod 3 = 0)]"
        );
        assert_eq!(
            xpath("e:nth-child(-n+6)"),
            "e[(count(preceding-sibling::*) <= 5)]"
        );
        assert_eq!(xpath("e:nth-child(n)"), "e");
        assert_eq!(xpath("e:nth-child(odd)"), xpath("e:nth-child(2n+1)"));
        assert_eq!(xpath("e:nth-child(even)"), xpath("e:nth-child(2n)"));
        // An+B is ASCII case-insensitive per css-syntax; Servo handles it
        // natively.
        assert_eq!(xpath("e:nth-child(2N)"), xpath("e:nth-child(2n)"));
        assert_eq!(xpath("e:nth-child(ODD)"), xpath("e:nth-child(odd)"));
        assert_eq!(xpath("e:nth-child(EVEN)"), xpath("e:nth-child(even)"));
        assert_eq!(xpath("e:nth-child(-N+3)"), xpath("e:nth-child(-n+3)"));
        assert_eq!(
            xpath("e:nth-last-child(1)"),
            "e[(count(following-sibling::*) = 0)]"
        );
        assert_eq!(
            xpath("e:nth-last-child(2n)"),
            "e[((count(following-sibling::*) +1) mod 2 = 0)]"
        );
        assert_eq!(
            xpath("e:nth-last-child(2n+1)"),
            "e[(count(following-sibling::*) mod 2 = 0)]"
        );
        assert_eq!(
            xpath("e:nth-last-child(2n+2)"),
            "e[(count(following-sibling::*) >= 1 and (count(following-sibling::*) +1) mod 2 = 0)]"
        );
        assert_eq!(
            xpath("e:nth-last-child(3n+1)"),
            "e[(count(following-sibling::*) mod 3 = 0)]"
        );
        assert_eq!(
            xpath("e:nth-last-child(-n+2)"),
            "e[(count(following-sibling::*) <= 1)]"
        );
        assert_eq!(
            xpath("e:nth-of-type(1)"),
            "e[(count(preceding-sibling::e) = 0)]"
        );
        assert_eq!(
            xpath("e:nth-last-of-type(1)"),
            "e[(count(following-sibling::e) = 0)]"
        );
        assert_eq!(
            xpath("div e:nth-last-of-type(1) .aclass"),
            "div//e[(count(following-sibling::e) = 0)]//*[(@class and \
             contains(concat(' ', normalize-space(@class), ' '), ' aclass '))]"
        );
        // Servo collapses :first-child & co. into nth data; the general
        // an+b form covers them (see translate::nth).
        assert_eq!(
            xpath("e:first-child"),
            "e[(count(preceding-sibling::*) = 0)]"
        );
        assert_eq!(
            xpath("e:last-child"),
            "e[(count(following-sibling::*) = 0)]"
        );
        assert_eq!(
            xpath("e:first-of-type"),
            "e[(count(preceding-sibling::e) = 0)]"
        );
        assert_eq!(
            xpath("e:last-of-type"),
            "e[(count(following-sibling::e) = 0)]"
        );
        assert_eq!(xpath("e:only-child"), "e[(count(parent::*/child::*) = 1)]");
        assert_eq!(
            xpath("e:only-of-type"),
            "e[(count(parent::*/child::e) = 1)]"
        );
        // Element names needing quoting fold into a name() condition; the
        // of-type pseudos count same-type siblings through the same test.
        assert_eq!(
            xpath("é:first-of-type"),
            "*[(name() = 'é') and (count(preceding-sibling::*[name() = 'é']) = 0)]"
        );
        assert_eq!(
            xpath("é:nth-of-type(2)"),
            "*[(name() = 'é') and (count(preceding-sibling::*[name() = 'é']) = 1)]"
        );
        assert_eq!(
            xpath("é:nth-last-of-type(1)"),
            "*[(name() = 'é') and (count(following-sibling::*[name() = 'é']) = 0)]"
        );
        assert_eq!(
            xpath("é:only-of-type"),
            "*[(name() = 'é') and (count(parent::*/child::*[name() = 'é']) = 1)]"
        );
        assert_eq!(
            xpath("e ~ f:nth-child(3)"),
            "e/following-sibling::f[(count(preceding-sibling::*) = 2)]"
        );
        // Early exits: a=1 with b<=1 matches everything; a<0 with b<1 is
        // impossible.
        assert_eq!(xpath("e:nth-child(n+1)"), "e");
        assert_eq!(xpath("e:nth-child(n-5)"), "e");
        assert_eq!(xpath("e:nth-child(-n)"), "e[(0)]");
        assert_eq!(xpath("e:nth-child(-2n-1)"), "e[(0)]");
        assert_eq!(xpath("e:nth-child(-n+0)"), "e[(0)]");
        assert_eq!(
            xpath("e:nth-child(-n+1)"),
            "e[(count(preceding-sibling::*) <= 0)]"
        );
        assert_eq!(
            xpath("e:nth-child(-2n+2)"),
            "e[(count(preceding-sibling::*) <= 1 and (count(preceding-sibling::*) +1) mod -2 = 0)]"
        );
    }

    /// `of S` selector lists (CSS Level 4), nth-child only.
    #[test]
    fn nth_child_of() {
        assert_eq!(
            xpath("div:nth-child(2 of .foo)"),
            "div[(count(preceding-sibling::*[(@class and contains(concat(' ', \
             normalize-space(@class), ' '), ' foo '))]) = 1) and ((@class and \
             contains(concat(' ', normalize-space(@class), ' '), ' foo ')))]"
        );
        // a=1, b<=1: only the current-element check remains.
        assert_eq!(
            xpath("li:nth-child(n of .item)"),
            "li[((@class and contains(concat(' ', normalize-space(@class), \
             ' '), ' item ')))]"
        );
        // Impossible series keeps the current-element check after the 0.
        assert_eq!(
            xpath("li:nth-child(-n of .item)"),
            "li[(0) and ((@class and contains(concat(' ', \
             normalize-space(@class), ' '), ' item ')))]"
        );
        // An element argument folds into a name() test.
        assert_eq!(
            xpath("div:nth-child(2 of div.foo)"),
            "div[(count(preceding-sibling::*[(@class and contains(concat(' ', \
             normalize-space(@class), ' '), ' foo ')) and (name() = 'div')]) = 1) \
             and ((@class and contains(concat(' ', normalize-space(@class), ' '), \
             ' foo ')) and (name() = 'div'))]"
        );
        // A universal argument makes the list match everything, like a
        // plain :nth-child.
        assert_eq!(
            xpath("li:nth-child(2 of .foo, *)"),
            "li[(count(preceding-sibling::*) = 1)]"
        );
    }

    /// Structural pseudos and the generic never-match set.
    #[test]
    fn structural_and_never_match_pseudos() {
        assert_eq!(xpath("e:empty"), "e[(not(*) and not(string-length()))]");
        assert_eq!(xpath("e:EmPTY"), "e[(not(*) and not(string-length()))]");
        assert_eq!(xpath("e:root"), "e[(not(parent::*))]");
        // The generic never-match set.
        for pseudo in [
            "any-link",
            "link",
            "visited",
            "hover",
            "active",
            "focus",
            "target",
            "target-within",
            "local-link",
            "enabled",
            "disabled",
            "checked",
        ] {
            assert_eq!(xpath(&format!("a:{pseudo}")), "a[(0)]");
        }
        assert_eq!(xpath("a:dir(ltr)"), "a[(0)]");
    }

    #[test]
    fn negation_matching_where_has() {
        assert_eq!(
            xpath("e:not(:nth-child(odd))"),
            "e[(not((count(preceding-sibling::*) mod 2 = 0)))]"
        );
        assert_eq!(xpath("e:nOT(*)"), "e[(0)]");
        assert_eq!(xpath("e:not(a)"), "e[(not((name() = 'a')))]");
        assert_eq!(
            xpath("e:not(a, b)"),
            "e[(not((name() = 'a') or (name() = 'b')))]"
        );
        // A universal argument makes :not() unmatchable...
        assert_eq!(xpath("div:not(a, *)"), "div[(0)]");
        // :where() / :is() OR their arguments together into one condition
        // that ANDs with the rest of the compound.
        assert_eq!(xpath("div:where(p)"), "div[((name() = 'p'))]");
        assert_eq!(
            xpath("div:where(p, span)"),
            "div[((name() = 'p') or (name() = 'span'))]"
        );
        assert_eq!(
            xpath("*:where(div.content)"),
            "*[((@class and contains(concat(' ', normalize-space(@class), \
             ' '), ' content ')) and (name() = 'div'))]"
        );
        assert_eq!(
            xpath("div:where(p):where(span)"),
            "div[((name() = 'p')) and ((name() = 'span'))]"
        );
        assert_eq!(xpath("div:is(p)"), "div[((name() = 'p'))]");
        // :matches() is the legacy alias for :is().
        assert_eq!(xpath("div:matches(p)"), "div[((name() = 'p'))]");
        // ...and :is()/:where() a no-op constraint.
        assert_eq!(xpath("e:is(*)"), "e");
        assert_eq!(xpath("div:is(a, *)"), "div");
        assert_eq!(xpath("div:where(a, *)"), "div");
        // :has().
        assert_eq!(xpath("div:has(p)"), "div[(.//*[(name() = 'p')])]");
        assert_eq!(
            xpath("div:has(.foo)"),
            "div[(.//*[(@class and contains(concat(' ', \
             normalize-space(@class), ' '), ' foo '))])]"
        );
        assert_eq!(
            xpath("div:has(p, span)"),
            "div[(.//*[(name() = 'p')] | .//*[(name() = 'span')])]"
        );
        assert_eq!(
            xpath("div:has(p):has(span)"),
            "div[(.//*[(name() = 'p')]) and (.//*[(name() = 'span')])]"
        );
        assert_eq!(
            xpath("section:has(div.content)"),
            "section[(.//*[(@class and contains(concat(' ', \
             normalize-space(@class), ' '), ' content ')) and \
             (name() = 'div')])]"
        );
        assert_eq!(xpath("div:has(*)"), "div[(.//*)]");
        // Leading combinators in :has() (selectors-4 relative selectors).
        assert_eq!(xpath("e:has(> img)"), "e[(child::*[(name() = 'img')])]");
        assert_eq!(
            xpath("e:has(~ p)"),
            "e[(following-sibling::*[(name() = 'p')])]"
        );
        assert_eq!(
            xpath("e:has(+ p)"),
            "e[(following-sibling::*[1][(name() = 'p')])]"
        );
        assert_eq!(
            xpath("e:has(> a, ~ p)"),
            "e[(child::*[(name() = 'a')] | following-sibling::*[(name() = 'p')])]"
        );
        assert_eq!(
            xpath("e:has(> .foo)"),
            "e[(child::*[(@class and contains(concat(' ', \
             normalize-space(@class), ' '), ' foo '))])]"
        );
        assert_eq!(
            xpath("e:has(+ p.foo)"),
            "e[(following-sibling::*[1][(@class and contains(concat(' ', \
             normalize-space(@class), ' '), ' foo ')) and (name() = 'p')])]"
        );
        // Nested :not() (Selectors Level 4).
        assert_eq!(xpath(":not(:not(a))"), "*[(not((not((name() = 'a')))))]");
        assert_eq!(xpath("e:is(:not(f))"), "e[((not((name() = 'f'))))]");
        assert_eq!(xpath("e:has(:not(f))"), "e[(.//*[(not((name() = 'f')))])]");
        // Prefixed names inside arguments stay node tests, resolved
        // through the namespace map like a top-level `svg|g` — not a
        // string comparison against the document's prefix.
        assert_eq!(xpath("e:is(svg|g)"), "e[((self::svg:g))]");
        assert_eq!(xpath("e:not(svg|g)"), "e[(not((self::svg:g)))]");
        assert_eq!(xpath("e:is(svg|*)"), "e[((self::svg:*))]");
        assert_eq!(xpath("e:has(svg|g)"), "e[(.//svg:g)]");
        assert_eq!(xpath("e:has(> svg|g)"), "e[(child::svg:g)]");
        assert_eq!(
            xpath("e:has(~ svg|g)"),
            "e[(following-sibling::svg:g)]"
        );
        assert_eq!(
            xpath("e:has(+ svg|g)"),
            "e[(following-sibling::*[1][(self::svg:g)])]"
        );
        assert_eq!(
            xpath("e:has(svg|g.foo)"),
            "e[(.//svg:g[(@class and contains(concat(' ', \
             normalize-space(@class), ' '), ' foo '))])]"
        );
    }

    #[test]
    fn lang_and_dir() {
        // Generic: XPath's lang() does prefix matching natively.
        assert_eq!(xpath("e:lang(en)"), "e[(lang('en'))]");
        assert_eq!(xpath("e:lang(\"en\")"), "e[(lang('en'))]");
        assert_eq!(xpath("e:lang(en-*)"), "e[(lang('en'))]");
        assert_eq!(xpath("e:lang(*)"), "e[(true())]");
        assert_eq!(xpath("e:lang(en, fr)"), "e[((lang('en') or lang('fr')))]");
        // Whitespace is a separator too.
        assert_eq!(xpath("e:lang(en fr)"), "e[((lang('en') or lang('fr')))]");
        // HTML: nearest lang-attributed ancestor, lowercased prefix match.
        let html = Translator::new("html").unwrap();
        assert_eq!(
            html.css_to_xpath("e:lang(EN)", "").unwrap(),
            "e[(ancestor-or-self::*[@lang][1][starts-with(concat(\
             translate(@lang, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', \
             'abcdefghijklmnopqrstuvwxyz'), '-'), 'en-')])]"
        );
        assert_eq!(
            html.css_to_xpath("e:lang(*)", "").unwrap(),
            "e[(ancestor-or-self::*[@lang])]"
        );
        // xhtml shares the HTML overrides.
        let xhtml = Translator::new("xhtml").unwrap();
        assert_eq!(
            xhtml.css_to_xpath("E:lang(*)", "").unwrap(),
            "E[(ancestor-or-self::*[@lang])]"
        );
        // :dir() takes exactly one identifier (selectors-4) — none of
        // :lang()'s strings, wildcards, or lists.
        let t = Translator::new("generic").unwrap();
        assert_eq!(xpath("e:dir(rtl)"), "e[(0)]");
        assert!(t.css_to_xpath("e:dir()", "").is_err());
        assert!(t.css_to_xpath("e:dir(ltr rtl)", "").is_err());
        assert!(t.css_to_xpath("e:dir(ltr, rtl)", "").is_err());
        assert!(t.css_to_xpath("e:dir(\"ltr\")", "").is_err());
        assert!(t.css_to_xpath("e:dir(*)", "").is_err());
    }

    /// The HTML translator's pseudo-class overrides.
    #[test]
    fn html_pseudo_overrides() {
        let html = Translator::new("html").unwrap();
        let h = |css: &str| html.css_to_xpath(css, "").unwrap();
        assert_eq!(
            h("a:link"),
            "a[(@href and (name(.) = 'a' or name(.) = 'link' or name(.) = 'area'))]"
        );
        assert_eq!(
            h("input:checked"),
            "input[((@selected and name(.) = 'option') or (@checked and \
             (name(.) = 'input' or name(.) = 'command')and (@type = 'checkbox' \
             or @type = 'radio')))]"
        );
        // Non-overridden dynamic pseudos still never match.
        assert_eq!(h("a:hover"), "a[(0)]");
        assert_eq!(h("a:visited"), "a[(0)]");
    }

    #[test]
    fn html_translator_lowercases_names_not_values() {
        let html = Translator::new("html").unwrap();
        assert_eq!(html.css_to_xpath("DIV", "").unwrap(), "div");
        assert_eq!(html.css_to_xpath("[FOO]", "").unwrap(), "*[(@foo)]");
        // Names lowercase, values keep their case.
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
