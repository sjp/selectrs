//! The `XPathExpr` builder and string helpers.
//!
//! The condition-parenthesization convention (output like `e[(@foo = 'bar')]`)
//! and the `*/`-collapse guard in `join` are load-bearing in
//! test-translation.R.

/// Whether a name can be used directly in an XPath name test (no quoting
/// needed).
pub fn is_safe_name(name: &str) -> bool {
    let mut chars = name.chars();
    let Some(first) = chars.next() else {
        return false;
    };
    if !(first.is_ascii_alphabetic() || first == '_') {
        return false;
    }
    chars.all(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '.' | '-'))
}

/// Quote a string as an XPath literal.
///
/// Note: each character is quoted individually in the `concat(...)`
/// branch — a quirk preserved because the exact output is pinned by tests.
pub fn xpath_literal(literal: &str) -> String {
    if !literal.contains('\'') {
        format!("'{literal}'")
    } else if !literal.contains('"') {
        format!("\"{literal}\"")
    } else {
        let parts: Vec<String> = literal
            .chars()
            .map(|c| {
                if c == '\'' {
                    format!("\"{c}\"")
                } else {
                    format!("'{c}'")
                }
            })
            .collect();
        format!("concat({})", parts.join(","))
    }
}

/// A partially built XPath expression: path, element, predicates, and
/// condition.
///
/// `condition` is stored *with* its wrapping parentheses (see
/// `add_condition`).
#[derive(Clone, Debug)]
pub struct XPathExpr {
    pub path: String,
    pub element: String,
    pub condition: String,
    /// Standalone predicates rendered each in its own bracket pair before
    /// the combined condition: `element[p1][p2][condition]`. Used where
    /// brackets must stay separate — e.g. the `+` combinator's `[1]`
    /// position test, which has to apply before any further filtering.
    predicates: Vec<String>,
    /// The element name `add_name_test` folded into a `name() = ...`
    /// condition, kept so the of-type pseudo-classes can still count
    /// same-type siblings.
    folded_name: Option<String>,
}

impl XPathExpr {
    pub fn new(element: &str) -> Self {
        XPathExpr {
            path: String::new(),
            element: element.to_owned(),
            condition: String::new(),
            predicates: Vec::new(),
            folded_name: None,
        }
    }

    pub fn str(&self) -> String {
        let mut p = format!("{}{}", self.path, self.element);
        for predicate in &self.predicates {
            p.push('[');
            p.push_str(predicate);
            p.push(']');
        }
        if !self.condition.is_empty() {
            p.push('[');
            p.push_str(&self.condition);
            p.push(']');
        }
        p
    }

    pub fn add_predicate(&mut self, predicate: &str) {
        self.predicates.push(predicate.to_owned());
    }

    pub fn add_condition(&mut self, condition: &str) {
        self.add_condition_with(condition, "and");
    }

    pub fn add_condition_with(&mut self, condition: &str, conjunction: &str) {
        self.condition = if self.condition.is_empty() {
            format!("({condition})")
        } else {
            format!("{} {conjunction} ({condition})", self.condition)
        };
    }

    pub fn add_name_test(&mut self) {
        if self.element == "*" {
            return;
        }
        let cond = format!("name() = {}", xpath_literal(&self.element));
        self.add_condition(&cond);
        self.folded_name = Some(std::mem::replace(&mut self.element, "*".to_owned()));
    }

    /// The node test selecting siblings of the same type, for the of-type
    /// pseudo-classes. `None` when the element is a genuine universal.
    pub fn same_type_nodetest(&self) -> Option<String> {
        if self.element != "*" {
            Some(self.element.clone())
        } else {
            self.folded_name
                .as_ref()
                .map(|name| format!("*[name() = {}]", xpath_literal(name)))
        }
    }

    /// Append `combiner` and `other` to this expression, collapsing a
    /// leading `*/` in `other`'s path.
    pub fn join(&mut self, combiner: &str, other: &XPathExpr) {
        let mut p = format!("{}{}", self.str(), combiner);
        if other.path != "*/" {
            p.push_str(&other.path);
        }
        self.path = p;
        self.element = other.element.clone();
        self.condition = other.condition.clone();
        self.predicates = other.predicates.clone();
        self.folded_name = other.folded_name.clone();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn safe_names() {
        assert!(is_safe_name("div"));
        assert!(is_safe_name("_x"));
        assert!(is_safe_name("a-b.c_1"));
        assert!(!is_safe_name("1a"));
        assert!(!is_safe_name("di[v"));
        assert!(!is_safe_name("di\u{a0}v"));
        assert!(!is_safe_name(""));
    }

    #[test]
    fn literals() {
        assert_eq!(xpath_literal("foo"), "'foo'");
        assert_eq!(xpath_literal("f'oo"), "\"f'oo\"");
        assert_eq!(xpath_literal("f'o\"o"), "concat('f',\"'\",'o','\"','o')");
    }

    #[test]
    fn condition_parens() {
        let mut xp = XPathExpr::new("e");
        xp.add_condition("@foo = 'bar'");
        assert_eq!(xp.str(), "e[(@foo = 'bar')]");
        xp.add_condition("@baz");
        assert_eq!(xp.str(), "e[(@foo = 'bar') and (@baz)]");
    }

    #[test]
    fn predicates_render_separately_before_condition() {
        let mut xp = XPathExpr::new("*");
        xp.add_predicate("1");
        xp.add_predicate("self::f");
        assert_eq!(xp.str(), "*[1][self::f]");
        xp.add_condition("@bar");
        assert_eq!(xp.str(), "*[1][self::f][(@bar)]");

        // join bakes the left side's predicates into the path and takes
        // over the right side's.
        let other = XPathExpr::new("g");
        xp.join("/following-sibling::", &other);
        assert_eq!(xp.str(), "*[1][self::f][(@bar)]/following-sibling::g");
        xp.add_predicate("1");
        assert_eq!(xp.str(), "*[1][self::f][(@bar)]/following-sibling::g[1]");
    }
}
