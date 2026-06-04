//! `SelectorImpl` and `Parser` implementations bridging Servo's `selectors`
//! crate to the selectrs translator.

pub mod impls;

use cssparser::{Parser as CssParser, ParserInput, ToCss};
use selectors::parser::{
    NonTSPseudoClass, ParseRelative, PseudoElement, SelectorImpl, SelectorList,
    SelectorParseErrorKind,
};
use std::fmt;

pub use impls::CssString;

use crate::translate::error::Error;

#[derive(Clone, Debug)]
pub struct SelectrsImpl;

impl SelectorImpl for SelectrsImpl {
    type ExtraMatchingData<'a> = ();
    type AttrValue = CssString;
    type Identifier = CssString;
    type LocalName = CssString;
    type NamespaceUrl = CssString;
    type NamespacePrefix = CssString;
    type BorrowedNamespaceUrl = str;
    type BorrowedLocalName = str;
    type NonTSPseudoClass = NeverPseudoClass;
    type PseudoElement = NeverPseudoElement;
}

/// Uninhabited: the `parse_non_ts_*` hooks are left at their erroring
/// defaults, so no non-tree-structural pseudo-class is ever constructed.
/// Unknown pseudos (`:contains` and friends) are rejected by the parser and
/// surface as errors — no custom handling needed.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum NeverPseudoClass {}

impl ToCss for NeverPseudoClass {
    fn to_css<W: fmt::Write>(&self, _dest: &mut W) -> fmt::Result {
        match *self {}
    }
}

impl NonTSPseudoClass for NeverPseudoClass {
    type Impl = SelectrsImpl;

    fn is_active_or_hover(&self) -> bool {
        match *self {}
    }

    fn is_user_action_state(&self) -> bool {
        match *self {}
    }
}

/// Uninhabited: `parse_pseudo_element` is left at its erroring default, so
/// `::before` etc. fail to parse — compatible with selectr, whose generic
/// translator errors on pseudo-elements too.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum NeverPseudoElement {}

impl ToCss for NeverPseudoElement {
    fn to_css<W: fmt::Write>(&self, _dest: &mut W) -> fmt::Result {
        match *self {}
    }
}

impl PseudoElement for NeverPseudoElement {
    type Impl = SelectrsImpl;
}

pub struct SelectrsParser;

impl<'i> selectors::parser::Parser<'i> for SelectrsParser {
    type Impl = SelectrsImpl;
    type Error = SelectorParseErrorKind<'i>;

    /// Strict everywhere: a selector that fails to parse must surface an
    /// error, never be silently dropped the way forgiving `:is()`/`:where()`
    /// parsing would.
    fn allow_forgiving_selectors(&self) -> bool {
        false
    }

    /// Identity mapping: `svg|g` translates to `svg:g` with no URL maps,
    /// matching selectr's prefix-only namespace model.
    fn namespace_for_prefix(&self, prefix: &CssString) -> Option<CssString> {
        Some(prefix.clone())
    }

    /// A sentinel "default namespace". Without one, Servo drops the
    /// namespace component from both `e` and `*|e` (they match identically),
    /// but selectr translates them differently (`e` vs a `local-name()`
    /// test). With it, plain `e` carries `DefaultNamespace("")` — mapped to
    /// "no constraint" — while `*|e` keeps `ExplicitAnyNamespace`. The empty
    /// string can never collide with a real prefix (prefixes are non-empty
    /// idents, and `namespace_for_prefix` is the identity).
    fn default_namespace(&self) -> Option<CssString> {
        Some(CssString::from(""))
    }
}

/// Parse a full selector list (comma-separated groups).
pub fn parse(css: &str) -> Result<SelectorList<SelectrsImpl>, Error> {
    let mut input = ParserInput::new(css);
    let mut parser = CssParser::new(&mut input);
    SelectorList::parse(&SelectrsParser, &mut parser, ParseRelative::No).map_err(|e| {
        let detail = match e.kind {
            cssparser::ParseErrorKind::Basic(ref kind) => format!("{kind:?}"),
            cssparser::ParseErrorKind::Custom(ref kind) => format!("{kind:?}"),
        };
        Error::Parse(format!(
            "{detail} (at {}:{})",
            e.location.line + 1,
            e.location.column
        ))
    })
}
