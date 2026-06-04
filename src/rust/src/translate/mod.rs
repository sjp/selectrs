//! Translation from Servo's parsed selector representation to XPath,
//! a branch-for-branch port of selectr's translators (R/xpath.R at
//! sjp/selectr@7327ae3).

pub mod error;
mod generic;
pub mod xpath_expr;

use selectors::attr::{NamespaceConstraint, ParsedAttrSelectorOperation, ParsedCaseSensitivity};
use selectors::parser::{Combinator, Component, Selector};

use crate::parser::{self, SelectrsImpl};
use error::Error;
use xpath_expr::{is_safe_name, XPathExpr};

/// One struct with lowercasing flags instead of R6 inheritance.
/// Casing is applied here in the translator, never via Servo's parser
/// settings, so generic-vs-html behavior matches selectr exactly.
pub struct Translator {
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
            "generic" | "xhtml" => Some(Translator {
                lower_case_element_names: false,
                lower_case_attribute_names: false,
            }),
            "html" => Some(Translator {
                lower_case_element_names: true,
                lower_case_attribute_names: true,
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
fn describe_component(component: &Component<SelectrsImpl>) -> String {
    match component {
        Component::Negation(..) => "the `:not()` pseudo-class".into(),
        Component::Root => "the `:root` pseudo-class".into(),
        Component::Empty => "the `:empty` pseudo-class".into(),
        Component::Scope | Component::ImplicitScope => "the `:scope` pseudo-class".into(),
        Component::Nth(..) | Component::NthOf(..) => {
            "an `:nth-child()`-family pseudo-class".into()
        },
        Component::Is(..) => "the `:is()` pseudo-class".into(),
        Component::Where(..) => "the `:where()` pseudo-class".into(),
        Component::Has(..) => "the `:has()` pseudo-class".into(),
        Component::Slotted(..) => "the `::slotted()` pseudo-element".into(),
        Component::Part(..) => "the `::part()` pseudo-element".into(),
        Component::Host(..) => "the `:host` pseudo-class".into(),
        Component::ParentSelector => "the `&` parent selector".into(),
        // NonTSPseudoClass / PseudoElement carry uninhabited types and the
        // remaining variants require parser features selectrs never enables;
        // they are unreachable, but erroring beats panicking (panic = abort
        // would terminate the R session).
        other => format!("an unexpected construct ({other:?})"),
    }
}
