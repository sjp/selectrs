//! The nth-child arithmetic and the structural pseudo-classes Servo folds
//! into `NthSelectorData`.
//!
//! Servo parses `:first-child` as `nth-child` data with `(a, b) = (0, 1)`,
//! `:last-child` as `nth-last-child(0n+1)`, and so on. That collapse is
//! lossless for translation: a dedicated `:first-child` translation would
//! produce byte-identical output to the general an+b form on the same
//! `(a, b)` (e.g. both give `count(preceding-sibling::*) = 0`). Only
//! `:only-child`/`:only-of-type` need their own translation.

use selectors::parser::{NthSelectorData, NthType, Selector};

use super::Translator;
use super::error::Error;
use super::xpath_expr::XPathExpr;
use crate::parser::SelectrsImpl;

impl Translator {
    /// Route one `NthSelectorData` (with Servo's pre-parsed `(a, b)`) to
    /// the matching translation. `selector_list` carries the Level 4
    /// `of S` arguments when present (`Component::NthOf`).
    pub(crate) fn apply_nth(
        &self,
        xpath: &mut XPathExpr,
        data: &NthSelectorData,
        selector_list: Option<&[Selector<SelectrsImpl>]>,
    ) -> Result<(), Error> {
        let a = data.an_plus_b.0;
        let b = data.an_plus_b.1;
        match data.ty {
            // :only-child
            NthType::OnlyChild => {
                xpath.add_condition("count(parent::*/child::*) = 1");
                Ok(())
            }
            // :only-of-type
            NthType::OnlyOfType => {
                if xpath.element == "*" {
                    return Err(Error::Unsupported(
                        "`:only-of-type` on the universal selector `*`".into(),
                    ));
                }
                xpath.add_condition(&format!("count(parent::*/child::{}) = 1", xpath.element));
                Ok(())
            }
            // :first-child / :last-child / :nth-child() / :nth-last-child()
            NthType::Child | NthType::LastChild => self.xpath_nth_child(
                xpath,
                a,
                b,
                /* last = */ data.ty == NthType::LastChild,
                /* add_name_test = */ true,
                selector_list,
            ),
            // :first-of-type / :last-of-type / :nth-of-type() /
            // :nth-last-of-type() — none are implemented on the universal
            // selector `*`.
            NthType::OfType | NthType::LastOfType => {
                if xpath.element == "*" {
                    return Err(Error::Unsupported(
                        "an of-type pseudo-class on the universal selector `*`".into(),
                    ));
                }
                self.xpath_nth_child(
                    xpath,
                    a,
                    b,
                    /* last = */ data.ty == NthType::LastOfType,
                    /* add_name_test = */ false,
                    selector_list,
                )
            }
        }
    }

    /// The general an+b translation, derived from
    /// https://www.w3.org/TR/selectors-4/#structural-pseudos.
    ///
    /// `add_name_test` is inverted and somewhat counter-intuitive:
    /// nth-of-type passes `false` and counts only siblings with the same
    /// element name.
    fn xpath_nth_child(
        &self,
        xpath: &mut XPathExpr,
        a: i32,
        b: i32,
        last: bool,
        add_name_test: bool,
        selector_list: Option<&[Selector<SelectrsImpl>]>,
    ) -> Result<(), Error> {
        // i64 throughout: `-(b-1)` / `abs(a)` must not overflow for
        // extreme i32 inputs.
        let a = i64::from(a);
        let b = i64::from(b);

        // work with b-1 instead
        let b_min_1 = b - 1;

        // CSS Level 4: when a selector list is provided, the current
        // element must match it too. The same OR-joined condition is
        // appended in every branch. A trivially-true list (it contains a
        // universal argument) constrains nothing, like a plain :nth-child.
        let current_element_check = match selector_list {
            Some(list) => self
                .arg_conditions(list, ":nth-child(... of S)")?
                .filter(|conditions| !conditions.is_empty())
                .map(|conditions| conditions.join(" or ")),
            None => None,
        };

        // early-exit condition 1:
        // ~~~~~~~~~~~~~~~~~~~~~~~
        // for a == 1, nth-*(an+b) means n+b-1 siblings before/after, and
        // since n is a non-negative integer, if b-1<=0 there is always an
        // "n" matching any number of siblings (maybe none)
        if a == 1 && b_min_1 <= 0 {
            if let Some(ref check) = current_element_check {
                xpath.add_condition(check);
            }
            return Ok(());
        }
        // early-exit condition 2:
        // ~~~~~~~~~~~~~~~~~~~~~~~
        // an+b-1 siblings with a<0 and (b-1)<0 is not possible
        if a < 0 && b_min_1 < 0 {
            xpath.add_condition("0");
            if let Some(ref check) = current_element_check {
                xpath.add_condition(check);
            }
            return Ok(());
        }

        let nodetest = if add_name_test {
            "*".to_owned()
        } else {
            xpath.element.clone()
        };

        // The predicate filtering counted siblings (CSS Level 4 `of S`) —
        // the same OR-joined conditions as the current-element check.
        let selector_predicate = match current_element_check {
            Some(ref check) => format!("[{check}]"),
            None => String::new(),
        };

        // count siblings before or after the element
        let axis = if last { "following" } else { "preceding" };
        let siblings_count = format!("count({axis}-sibling::{nodetest}{selector_predicate})");

        // special case of fixed position: nth-*(0n+b)
        if a == 0 {
            xpath.add_condition(&format!("{siblings_count} = {b_min_1}"));
            if let Some(ref check) = current_element_check {
                xpath.add_condition(check);
            }
            return Ok(());
        }

        let mut expr: Vec<String> = Vec::new();

        if a > 0 {
            // siblings count, an+b-1, is always >= 0, so if a>0 and
            // (b-1)<=0 an "n" exists to satisfy this; the predicate is
            // only interesting if (b-1)>0
            if b_min_1 > 0 {
                expr.push(format!("{siblings_count} >= {b_min_1}"));
            }
        } else {
            // a<0 with (b-1)<0 was the early exit above; otherwise:
            expr.push(format!("{siblings_count} <= {b_min_1}"));
        }

        // operations modulo 1 or -1 are simpler: the >=/<= test above
        // already covers them
        if a.abs() != 1 {
            // count(***-sibling::***) - (b-1) = 0 (mod a)
            let mut left = siblings_count;

            // apply "modulo a" on the 2nd term, -(b-1), to simplify things
            // like "(... +6) % -3", and also make it positive with |a|
            // (`rem_euclid`)
            let b_neg = (-b_min_1).rem_euclid(a.abs());

            if b_neg != 0 {
                left = format!("({left} +{b_neg})");
            }

            expr.push(format!("{left} mod {a} = 0"));
        }

        if !expr.is_empty() {
            xpath.add_condition(&expr.join(" and "));
        }

        if let Some(ref check) = current_element_check {
            xpath.add_condition(check);
        }

        Ok(())
    }
}
