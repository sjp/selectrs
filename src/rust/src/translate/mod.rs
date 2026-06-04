//! Translation from Servo's parsed selector representation to XPath,
//! a branch-for-branch port of selectr's translators (R/xpath.R at
//! sjp/selectr@7327ae3).

pub mod error;
mod generic;
mod nth;
mod pseudo;
pub mod xpath_expr;

use selectors::attr::{NamespaceConstraint, ParsedAttrSelectorOperation, ParsedCaseSensitivity};
use selectors::parser::{Combinator, Component, Selector};

use crate::parser::{self, SelectrsImpl};
use error::Error;
use xpath_expr::{is_safe_name, XPathExpr};

/// Which translator family the pseudo-class overrides come from: selectr's
/// `GenericTranslator` or `HTMLTranslator` (both `html` and `xhtml` use the
/// HTML overrides; only `html` lowercases names, R/xpath.R:1002-1013).
#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum Kind {
    Generic,
    Html,
}

/// One struct with a kind tag and lowercasing flags instead of R6
/// inheritance. Casing is applied here in the translator, never via Servo's
/// parser settings, so generic-vs-html behavior matches selectr exactly.
pub struct Translator {
    pub(crate) kind: Kind,
    pub(crate) lower_case_element_names: bool,
    pub(crate) lower_case_attribute_names: bool,
}

/// The namespace constraint on a type or attribute selector, mirroring
/// selectr's `namespace` field values at sjp/selectr@717e2ee:
/// `NULL` (none written), `"*"` (any), `""` (explicitly none), or a prefix.
#[derive(Clone, Copy)]
enum NsConstraint<'a> {
    /// No namespace separator written (`e`, `[foo]`).
    None,
    /// `*|e`, `[*|foo]`: any namespace, including none.
    Any,
    /// `|e`, `[|foo]`: explicitly no namespace.
    ExplicitNone,
    /// `ns|e`, `[ns|foo]`: a specific prefix (identity-mapped, no URL).
    Prefix(&'a str),
}

impl Translator {
    pub fn new(kind: &str) -> Option<Self> {
        match kind {
            "generic" => Some(Translator {
                kind: Kind::Generic,
                lower_case_element_names: false,
                lower_case_attribute_names: false,
            }),
            "html" => Some(Translator {
                kind: Kind::Html,
                lower_case_element_names: true,
                lower_case_attribute_names: true,
            }),
            "xhtml" => Some(Translator {
                kind: Kind::Html,
                lower_case_element_names: false,
                lower_case_attribute_names: false,
            }),
            _ => None,
        }
    }

    /// Port of `GenericTranslator$css_to_xpath` (R/xpath.R:112-131):
    /// comma-separated selector groups, each prefixed, joined with " | ".
    pub fn css_to_xpath(&self, css: &str, prefix: &str) -> Result<String, Error> {
        let list = parser::parse(css)?;
        let mut parts: Vec<String> = Vec::new();
        for sel in list.slice() {
            parts.push(self.selector_to_xpath(sel, prefix)?);
        }
        Ok(parts.join(" | "))
    }

    /// Iteration bridge: Servo iterates compound selectors right-to-left
    /// (match order); selectr's translator folds left-to-right over its
    /// `CombinedSelector` tree. Collect Servo's sequences + combinators,
    /// then fold from the leftmost compound.
    fn selector_to_xpath(
        &self,
        selector: &Selector<SelectrsImpl>,
        prefix: &str,
    ) -> Result<String, Error> {
        let mut iter = selector.iter();
        // seqs[i] = (compound, combinator between this compound and the one
        // to its left); match order, so seqs[0] is the rightmost compound.
        let mut seqs: Vec<(Vec<&Component<SelectrsImpl>>, Option<Combinator>)> = Vec::new();
        loop {
            let mut compound = Vec::new();
            for component in &mut iter {
                compound.push(component);
            }
            let combinator = iter.next_sequence();
            let done = combinator.is_none();
            seqs.push((compound, combinator));
            if done {
                break;
            }
        }

        // Leftmost compound first, then fold rightwards.
        let leftmost = seqs.len() - 1;
        let mut xpath = self.compound_to_xpath(&seqs[leftmost].0)?;
        for i in (0..leftmost).rev() {
            let combinator = seqs[i]
                .1
                .ok_or_else(|| Error::Unsupported("an unexpected selector structure".into()))?;
            let right = self.compound_to_xpath(&seqs[i].0)?;
            xpath = self.apply_combinator(combinator, xpath, &right)?;
        }

        Ok(format!("{prefix}{}", xpath.str()))
    }

    /// Translate one compound selector (a sequence of simple selectors).
    /// Element-ish components (namespace, type) always precede condition
    /// components in a valid compound; conditions are applied in source
    /// order, matching selectr's innermost-first AST recursion.
    fn compound_to_xpath(
        &self,
        components: &[&Component<SelectrsImpl>],
    ) -> Result<XPathExpr, Error> {
        let mut ns = NsConstraint::None;
        let mut element: Option<&str> = None;
        let mut xpath: Option<XPathExpr> = None;

        for component in components {
            match component {
                Component::Namespace(prefix, _) if xpath.is_none() => {
                    ns = NsConstraint::Prefix(prefix.as_str());
                },
                // The sentinel default namespace (see SelectrsParser):
                // plain `e` and type-less compounds — no constraint written.
                Component::DefaultNamespace(_) if xpath.is_none() => {
                    ns = NsConstraint::None;
                },
                Component::ExplicitAnyNamespace if xpath.is_none() => {
                    ns = NsConstraint::Any;
                },
                Component::ExplicitNoNamespace if xpath.is_none() => {
                    ns = NsConstraint::ExplicitNone;
                },
                Component::ExplicitUniversalType if xpath.is_none() => {},
                Component::LocalName(local_name) if xpath.is_none() => {
                    element = Some(local_name.name.as_str());
                },
                other => {
                    let xp = match xpath {
                        Some(ref mut xp) => xp,
                        None => {
                            xpath = Some(self.xpath_element(ns, element));
                            xpath.as_mut().expect("just set")
                        },
                    };
                    self.apply_simple(xp, other)?;
                },
            }
        }

        Ok(match xpath {
            Some(xp) => xp,
            None => self.xpath_element(ns, element),
        })
    }

    /// Port of `xpath_element` (R/xpath.R:412-452 at sjp/selectr@717e2ee).
    fn xpath_element(&self, ns: NsConstraint, element: Option<&str>) -> XPathExpr {
        let (mut name, mut safe) = match element {
            None => ("*".to_owned(), true),
            Some(e) => {
                let safe = is_safe_name(e);
                let e = if self.lower_case_element_names {
                    e.to_lowercase()
                } else {
                    e.to_owned()
                };
                (e, safe)
            },
        };
        match ns {
            NsConstraint::Any if name != "*" => {
                // '*|e': 'e' in any namespace, including none. An unprefixed
                // XPath name test only matches the null namespace, so test
                // against local-name() instead.
                let mut xpath = XPathExpr::new("*");
                xpath.add_condition(&format!("local-name() = {}", xpath_expr::xpath_literal(&name)));
                return xpath;
            },
            NsConstraint::ExplicitNone if name == "*" => {
                // '|e': 'e' in no namespace, which is exactly what an
                // unprefixed XPath name test matches. '|*' needs an
                // explicit namespace-uri() check.
                let mut xpath = XPathExpr::new("*");
                xpath.add_condition("namespace-uri() = ''");
                return xpath;
            },
            NsConstraint::Prefix(prefix) => {
                // Namespace prefixes are case-sensitive.
                // https://www.w3.org/TR/css-namespaces-3/#prefixes
                safe = safe && is_safe_name(prefix);
                name = format!("{prefix}:{name}");
            },
            // '*|*' and '|e' translate to an unqualified name test.
            _ => {},
        }
        let mut xpath = XPathExpr::new(&name);
        if !safe {
            xpath.add_name_test();
        }
        xpath
    }

    /// Dispatch over the non-element components of a compound — the
    /// allow-list over `Component` variants. Anything outside selectr's
    /// construct set errors, never approximates.
    fn apply_simple(
        &self,
        xpath: &mut XPathExpr,
        component: &Component<SelectrsImpl>,
    ) -> Result<(), Error> {
        match component {
            // :root (R/xpath.R:847-850)
            Component::Root => {
                xpath.add_condition("not(parent::*)");
                Ok(())
            },
            // :empty (R/xpath.R:887-890)
            Component::Empty => {
                xpath.add_condition("not(*) and not(string-length())");
                Ok(())
            },
            // :first-child, :nth-child(an+b), :only-of-type, ... — Servo
            // collapses the whole family into NthSelectorData.
            Component::Nth(data) => self.apply_nth(xpath, data, None),
            // :nth-child(an+b of S) / :nth-last-child(an+b of S)
            Component::NthOf(data) => {
                self.apply_nth(xpath, data.nth_data(), Some(data.selectors()))
            },
            // :not() — port of xpath_negation (R/xpath.R:196-217). Nesting
            // inside other functional pseudo-classes is allowed (Selectors
            // Level 4, sjp/selectr@2a9ebb5).
            Component::Negation(list) => {
                let conditions = self.arg_conditions(list.slice(), ":not()")?;
                if !conditions.is_empty() {
                    xpath.add_condition(&format!("not({})", conditions.join(" or ")));
                } else {
                    xpath.add_condition("0");
                }
                Ok(())
            },
            // :is()/:matches() and :where() — ports of xpath_matching and
            // xpath_where (R/xpath.R:218-245), which are identical: each
            // argument's condition is OR-ed onto the outer expression.
            Component::Is(list) => {
                for condition in self.arg_conditions(list.slice(), ":is()")? {
                    xpath.add_condition_with(&condition, "or");
                }
                Ok(())
            },
            Component::Where(list) => {
                for condition in self.arg_conditions(list.slice(), ":where()")? {
                    xpath.add_condition_with(&condition, "or");
                }
                Ok(())
            },
            // :has() — port of xpath_has (R/xpath.R at sjp/selectr@9ed9bb2):
            // each argument is a relative selector whose optional leading
            // combinator scopes the match (`>` child, `~` subsequent
            // sibling, `+` next sibling; omitted means descendant).
            // selectr's parser still only accepts one compound after the
            // combinator, so Servo's full complex-selector forms must error.
            Component::Has(relatives) => {
                let mut conditions: Vec<String> = Vec::new();
                for relative in relatives.iter() {
                    let mut iter = relative.selector.iter();
                    let mut compound: Vec<&Component<SelectrsImpl>> = Vec::new();
                    for c in &mut iter {
                        compound.push(c);
                    }
                    let combinator = iter.next_sequence();
                    let anchor: Vec<&Component<SelectrsImpl>> = (&mut iter).collect();
                    let anchor_only = anchor.len() == 1
                        && matches!(anchor[0], Component::RelativeSelectorAnchor)
                        && iter.next_sequence().is_none();
                    if !anchor_only {
                        return Err(Error::Unsupported(
                            "a complex selector (with combinators) inside `:has()`".into(),
                        ));
                    }
                    let axis = match combinator {
                        Some(Combinator::Descendant) => ".//",
                        Some(Combinator::Child) => "child::",
                        Some(Combinator::NextSibling) | Some(Combinator::LaterSibling) => {
                            "following-sibling::"
                        },
                        _ => {
                            return Err(Error::Unsupported(
                                "an unexpected combinator inside `:has()`".into(),
                            ));
                        },
                    };
                    let mut sub = self.compound_to_xpath(&compound)?;
                    sub.add_name_test();
                    let mut rel_test = format!("{axis}{}", sub.element);
                    if matches!(combinator, Some(Combinator::NextSibling)) {
                        // Only the immediately following sibling: constrain
                        // position before applying the match conditions.
                        rel_test.push_str("[1]");
                    }
                    if !sub.condition.is_empty() {
                        rel_test.push('[');
                        rel_test.push_str(&sub.condition);
                        rel_test.push(']');
                    }
                    conditions.push(rel_test);
                }
                if !conditions.is_empty() {
                    xpath.add_condition(&conditions.join(" | "));
                }
                Ok(())
            },
            // :hover, :checked, :lang(), ... — translator-dependent.
            Component::NonTSPseudoClass(pc) => self.apply_pseudo_class(xpath, pc),
            // e#myid (R/xpath.R:394-398)
            Component::ID(id) => {
                self.attrib_equals(xpath, "@id", id.as_str());
                Ok(())
            },
            // .foo is defined as [class~=foo] in the spec (R/xpath.R:387-393)
            Component::Class(class_name) => {
                self.attrib_includes(xpath, "@class", class_name.as_str());
                Ok(())
            },
            Component::AttributeInNoNamespaceExists { local_name, .. } => {
                let attrib = self.attrib_expr(NsConstraint::None, local_name.as_str());
                xpath.add_condition(&attrib);
                Ok(())
            },
            Component::AttributeInNoNamespace {
                local_name,
                operator,
                value,
                case_sensitivity,
            } => {
                let attrib = self.attrib_expr(NsConstraint::None, local_name.as_str());
                let (attrib, value) =
                    apply_case_flag(attrib, value.as_str(), case_sensitivity);
                self.attrib_operator(xpath, &attrib, *operator, &value)
            },
            Component::AttributeOther(attr) => {
                let ns = match attr.namespace {
                    Some(NamespaceConstraint::Specific((ref prefix, _))) => {
                        NsConstraint::Prefix(prefix.as_str())
                    },
                    Some(NamespaceConstraint::Any) => NsConstraint::Any,
                    // '[|foo]' is equivalent to '[foo]': unprefixed
                    // attribute names have no namespace.
                    None => NsConstraint::None,
                };
                let attrib = self.attrib_expr(ns, attr.local_name.as_str());
                match attr.operation {
                    ParsedAttrSelectorOperation::Exists => {
                        xpath.add_condition(&attrib);
                        Ok(())
                    },
                    ParsedAttrSelectorOperation::WithValue {
                        operator,
                        case_sensitivity,
                        ref value,
                    } => {
                        let (attrib, value) =
                            apply_case_flag(attrib, value.as_str(), &case_sensitivity);
                        self.attrib_operator(xpath, &attrib, operator, &value)
                    },
                }
            },
            unsupported => Err(Error::Unsupported(describe_component(unsupported))),
        }
    }

    /// Port of the attribute-name handling in `xpath_attrib`
    /// (R/xpath.R:347-376 at sjp/selectr@717e2ee): lowercase (html), safety
    /// check, namespace qualification (note: a specific namespace prefix is
    /// not part of the safety check, mirroring selectr exactly).
    fn attrib_expr(&self, ns: NsConstraint, local_name: &str) -> String {
        let name = if self.lower_case_attribute_names {
            local_name.to_lowercase()
        } else {
            local_name.to_owned()
        };
        let safe = is_safe_name(&name);
        match ns {
            NsConstraint::Any => {
                // '[*|attr]': 'attr' in any namespace, including none. An
                // unprefixed XPath attribute test only matches attributes
                // with no namespace, so test against local-name() instead.
                format!("@*[local-name() = {}]", xpath_expr::xpath_literal(&name))
            },
            NsConstraint::Prefix(prefix) => {
                let name = format!("{prefix}:{name}");
                if safe {
                    format!("@{name}")
                } else {
                    format!(
                        "attribute::*[name() = {}]",
                        xpath_expr::xpath_literal(&name)
                    )
                }
            },
            NsConstraint::None | NsConstraint::ExplicitNone => {
                if safe {
                    format!("@{name}")
                } else {
                    format!(
                        "attribute::*[name() = {}]",
                        xpath_expr::xpath_literal(&name)
                    )
                }
            },
        }
    }

    /// Port of the four `xpath_*_combinator` methods (R/xpath.R:420-445).
    fn apply_combinator(
        &self,
        combinator: Combinator,
        mut left: XPathExpr,
        right: &XPathExpr,
    ) -> Result<XPathExpr, Error> {
        match combinator {
            Combinator::Descendant => left.join("//", right),
            Combinator::Child => left.join("/", right),
            Combinator::LaterSibling => left.join("/following-sibling::", right),
            Combinator::NextSibling => {
                left.join("/following-sibling::", right);
                let target_element = left.element.clone();
                let existing_condition = left.condition.clone();
                left.add_name_test();
                left.condition = if existing_condition.is_empty() {
                    // No existing conditions, just position and element test
                    format!("1][self::{target_element}")
                } else {
                    // Has existing conditions from right selector (e.g.,
                    // attributes). Result: *[1][self::element][existing]
                    format!("1][self::{target_element}][{existing_condition}")
                };
            },
            // PseudoElement / SlotAssignment / Part combinators can never be
            // produced: the corresponding parser hooks are disabled.
            other => {
                return Err(Error::Unsupported(format!(
                    "the {other:?} combinator"
                )));
            },
        }
        Ok(left)
    }

    /// Harvest the conditions of a pseudo-class argument list, the shared
    /// pattern of xpath_negation/xpath_matching/xpath_where and the nth
    /// `of S` handling (R/xpath.R:199-207, 222-227, 628-634): translate
    /// each argument, fold its element into a `name()` condition via
    /// `add_name_test`, and keep the non-empty conditions (each still
    /// carrying its outer parentheses, exactly as selectr's `$condition`
    /// field does).
    ///
    /// selectr's argument grammar only admits compound selectors — a
    /// combinator inside `:is(a b)` is a parse error there
    /// ("Expected an argument", R/parser.R:686-726) — so complex selectors
    /// error here.
    fn arg_conditions(
        &self,
        selectors: &[Selector<SelectrsImpl>],
        context: &str,
    ) -> Result<Vec<String>, Error> {
        let mut conditions = Vec::new();
        for selector in selectors {
            let mut iter = selector.iter();
            let mut compound: Vec<&Component<SelectrsImpl>> = Vec::new();
            for component in &mut iter {
                compound.push(component);
            }
            if iter.next_sequence().is_some() {
                return Err(Error::Unsupported(format!(
                    "a complex selector (with combinators) inside `{context}`"
                )));
            }
            let mut sub = self.compound_to_xpath(&compound)?;
            sub.add_name_test();
            if !sub.condition.is_empty() {
                conditions.push(sub.condition);
            }
        }
        Ok(conditions)
    }
}

/// Port of the Level 4 case-sensitivity flag handling in `xpath_attrib`
/// (R/xpath.R:383-398 at sjp/selectr@7776605).
///
/// `[attr="value" i]`: compare the ASCII-lowercased attribute (via XPath
/// `translate()`) against the ASCII-lowercased value. An empty value needs
/// no lowercasing, and skipping it keeps the existence tests exact. The `s`
/// flag, the no-flag default, and Servo's HTML-legacy-attribute default all
/// mean the ordinary case-sensitive translation.
fn apply_case_flag(
    attrib: String,
    value: &str,
    case_sensitivity: &ParsedCaseSensitivity,
) -> (String, String) {
    match case_sensitivity {
        ParsedCaseSensitivity::AsciiCaseInsensitive if !value.is_empty() => (
            format!(
                "translate({attrib}, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', \
                 'abcdefghijklmnopqrstuvwxyz')"
            ),
            value.to_ascii_lowercase(),
        ),
        _ => (attrib, value.to_owned()),
    }
}

/// Human-readable construct names for unsupported-error messages.
/// selectr treats these as unknown pseudo-classes too
/// ("The pseudo-class :scope is unknown", R/xpath.R:344-345).
fn describe_component(component: &Component<SelectrsImpl>) -> String {
    match component {
        Component::Scope | Component::ImplicitScope => "the `:scope` pseudo-class".into(),
        Component::Slotted(..) => "the `::slotted()` pseudo-element".into(),
        Component::Part(..) => "the `::part()` pseudo-element".into(),
        Component::Host(..) => "the `:host` pseudo-class".into(),
        Component::ParentSelector => "the `&` parent selector".into(),
        // PseudoElement carries an uninhabited type and the remaining
        // variants require parser features selectrs never enables; they are
        // unreachable, but erroring beats panicking (panic = abort would
        // terminate the R session).
        other => format!("an unexpected construct ({other:?})"),
    }
}
