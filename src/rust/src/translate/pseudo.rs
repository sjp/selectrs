//! Port of the non-tree-structural pseudo-class translations: selectr's
//! "never matches" set (R/xpath.R:892-909), the `HTMLTranslator` overrides
//! (R/xpath.R:1002-1156), and `:lang()`/`:dir()` (R/xpath.R:775-846).
//!
//! Both `html` and `xhtml` use the HTML overrides (`HTMLTranslator$new`
//! only varies the lowercasing flags); the generic translator answers `0`
//! (never matches) for everything except `:lang()`, which it maps to
//! XPath's `lang()` function.

use crate::parser::{LangArg, PseudoClass};

use super::error::Error;
use super::xpath_expr::{xpath_literal, XPathExpr};
use super::{Kind, Translator};

/// The HTML translators' lang attribute (`self$lang_attribute <- "lang"`,
/// R/xpath.R:1012). The generic translator's `"xml:lang"` is never used in
/// translation — its `:lang()` goes through XPath's `lang()` function.
const LANG_ATTRIBUTE: &str = "lang";

impl Translator {
    pub(crate) fn apply_pseudo_class(
        &self,
        xpath: &mut XPathExpr,
        pc: &PseudoClass,
    ) -> Result<(), Error> {
        match (self.kind, pc) {
            (_, PseudoClass::Dir(_)) => {
                // :dir() requires runtime directionality detection, not
                // possible in static XPath, so it never matches — in both
                // translators (the HTML override is an identical copy).
                xpath.add_condition("0");
            },
            (Kind::Generic, PseudoClass::Lang(args)) => {
                self.lang_generic(xpath, args);
            },
            (Kind::Html, PseudoClass::Lang(args)) => {
                self.lang_html(xpath, args);
            },
            // HTMLTranslator overrides (R/xpath.R:1014-1154)
            (Kind::Html, PseudoClass::Checked) => {
                xpath.add_condition(
                    "(@selected and name(.) = 'option') or \
                     (@checked \
                     and (name(.) = 'input' or name(.) = 'command')\
                     and (@type = 'checkbox' or @type = 'radio'))",
                );
            },
            (Kind::Html, PseudoClass::Link) => {
                xpath.add_condition(
                    "@href and (name(.) = 'a' or name(.) = 'link' or name(.) = 'area')",
                );
            },
            (Kind::Html, PseudoClass::Disabled) => {
                xpath.add_condition(
                    "( @disabled and ( \
                     (name(.) = 'input' and @type != 'hidden') or \
                     name(.) = 'button' or \
                     name(.) = 'select' or \
                     name(.) = 'textarea' or \
                     name(.) = 'command' or \
                     name(.) = 'fieldset' or \
                     name(.) = 'optgroup' or \
                     name(.) = 'option' \
                     ) ) or ( ( \
                     (name(.) = 'input' and @type != 'hidden') or \
                     name(.) = 'button' or \
                     name(.) = 'select' or \
                     name(.) = 'textarea' \
                     ) \
                     and ancestor::fieldset[@disabled] \
                     )",
                );
            },
            (Kind::Html, PseudoClass::Enabled) => {
                xpath.add_condition(
                    "(@href and (name(.) = 'a' or name(.) = 'link' or name(.) = 'area')) \
                     or \
                     ((name(.) = 'command' or name(.) = 'fieldset' or name(.) = 'optgroup') \
                     and not(@disabled)) \
                     or \
                     (((name(.) = 'input' and @type != 'hidden') \
                     or name(.) = 'button' \
                     or name(.) = 'select' \
                     or name(.) = 'textarea' \
                     or name(.) = 'keygen') \
                     and not (@disabled or ancestor::fieldset[@disabled])) \
                     or (name(.) = 'option' and not(@disabled or \
                     ancestor::optgroup[@disabled]))",
                );
            },
            // Everything else never matches (R/xpath.R:897-909).
            _ => {
                xpath.add_condition("0");
            },
        }
        Ok(())
    }

    /// Port of the generic `xpath_lang_function` (R/xpath.R:775-831):
    /// XPath's `lang()` does language-range prefix matching natively, so
    /// `en` and `en-*` both become `lang('en')`-style tests and a bare `*`
    /// is `true()`.
    fn lang_generic(&self, xpath: &mut XPathExpr, args: &[LangArg]) {
        let mut conditions: Vec<String> = Vec::new();
        for value in lang_values(args) {
            if value == "*" {
                conditions.push("true()".to_owned());
            } else if let Some(prefix) = value.strip_suffix('*') {
                conditions.push(format!("lang({})", xpath_literal(prefix)));
            } else {
                conditions.push(format!("lang({})", xpath_literal(&value)));
            }
        }
        add_lang_conditions(xpath, conditions);
    }

    /// Port of the HTML `xpath_lang_function` override (R/xpath.R:1022-1095):
    /// the nearest `lang`-attributed ancestor-or-self is tested with a
    /// lowercased, dash-terminated prefix match.
    fn lang_html(&self, xpath: &mut XPathExpr, args: &[LangArg]) {
        let mut conditions: Vec<String> = Vec::new();
        for value in lang_values(args) {
            if value == "*" {
                // Wildcard * matches any element with a lang attribute.
                conditions.push(format!("ancestor-or-self::*[@{LANG_ATTRIBUTE}]"));
            } else if let Some(prefix) = value.strip_suffix('*') {
                // Wildcard suffix like "en-*": don't add '-' if the prefix
                // already ends with it.
                let search_prefix = if prefix.ends_with('-') {
                    prefix.to_lowercase()
                } else {
                    format!("{}-", prefix.to_lowercase())
                };
                conditions.push(lang_ancestor_condition(&search_prefix));
            } else {
                conditions.push(lang_ancestor_condition(&format!(
                    "{}-",
                    value.to_lowercase()
                )));
            }
        }
        add_lang_conditions(xpath, conditions);
    }
}

/// Combine the raw `:lang()`/`:dir()` arguments into language values,
/// merging an ident/string ending in `-` with an immediately following `*`
/// (`"en-" + "*"` becomes `"en-*"`, R/xpath.R:786-803). Whitespace between
/// them doesn't matter: selectr drops whitespace tokens while collecting
/// arguments, so adjacency is in the argument list, not the source.
fn lang_values(args: &[LangArg]) -> Vec<String> {
    let mut values = Vec::new();
    let mut i = 0;
    while i < args.len() {
        match &args[i] {
            LangArg::Value(v)
                if v.ends_with('-') && matches!(args.get(i + 1), Some(LangArg::Star)) =>
            {
                values.push(format!("{v}*"));
                i += 2; // skip the next token since we combined it
            },
            LangArg::Value(v) => {
                values.push(v.clone());
                i += 1;
            },
            LangArg::Star => {
                values.push("*".to_owned());
                i += 1;
            },
        }
    }
    values
}

/// The shared condition-combining tail of both `xpath_lang_function`s
/// (R/xpath.R:822-830, 1086-1094): a single condition is added as-is,
/// multiple are OR-joined inside an extra pair of parentheses.
fn add_lang_conditions(xpath: &mut XPathExpr, conditions: Vec<String>) {
    match conditions.len() {
        0 => {},
        1 => xpath.add_condition(&conditions[0]),
        _ => xpath.add_condition(&format!("({})", conditions.join(" or "))),
    }
}

/// The HTML nearest-ancestor language test (R/xpath.R:1064-1082).
fn lang_ancestor_condition(search_prefix: &str) -> String {
    format!(
        "ancestor-or-self::*[@{LANG_ATTRIBUTE}][1][starts-with(concat(\
         translate(@{LANG_ATTRIBUTE}, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', \
         'abcdefghijklmnopqrstuvwxyz'), '-'), {})]",
        xpath_literal(search_prefix)
    )
}
