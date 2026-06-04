//! `SelectorImpl` and `Parser` implementations bridging Servo's `selectors`
//! crate to the selectrs translator.

pub mod impls;

use cssparser::{
    match_ignore_ascii_case, Parser as CssParser, ParserInput, SourceLocation, ToCss, Token,
};
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
    type NonTSPseudoClass = PseudoClass;
    type PseudoElement = NeverPseudoElement;
}

/// One argument to `:lang()` / `:dir()`: an ident or string value, or a
/// bare `*` wildcard. selectr collects these as raw tokens (commas and
/// whitespace are separators) and combines `xx-` followed by `*` into
/// `xx-*` at translation time (R/parser.R:626-668, R/xpath.R:775-831).
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum LangArg {
    Value(String),
    Star,
}

/// The non-tree-structural pseudo-classes selectr's translators know
/// (R/xpath.R:297-345). Everything here is the "never matches" set under
/// the generic translator; the HTML translator overrides `:checked`,
/// `:link`, `:enabled`, `:disabled`, and `:lang()`. Any other pseudo name
/// is rejected at parse time, matching selectr's "pseudo-class is unknown"
/// errors (tree-structural pseudos are parsed natively by Servo and never
/// reach this type).
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum PseudoClass {
    AnyLink,
    Link,
    Visited,
    Hover,
    Active,
    Focus,
    Target,
    TargetWithin,
    LocalLink,
    Enabled,
    Disabled,
    Checked,
    Lang(Vec<LangArg>),
    Dir(Vec<LangArg>),
}

impl PseudoClass {
    fn name(&self) -> &'static str {
        match self {
            PseudoClass::AnyLink => "any-link",
            PseudoClass::Link => "link",
            PseudoClass::Visited => "visited",
            PseudoClass::Hover => "hover",
            PseudoClass::Active => "active",
            PseudoClass::Focus => "focus",
            PseudoClass::Target => "target",
            PseudoClass::TargetWithin => "target-within",
            PseudoClass::LocalLink => "local-link",
            PseudoClass::Enabled => "enabled",
            PseudoClass::Disabled => "disabled",
            PseudoClass::Checked => "checked",
            PseudoClass::Lang(_) => "lang",
            PseudoClass::Dir(_) => "dir",
        }
    }
}

impl ToCss for PseudoClass {
    fn to_css<W: fmt::Write>(&self, dest: &mut W) -> fmt::Result {
        dest.write_char(':')?;
        dest.write_str(self.name())?;
        match self {
            PseudoClass::Lang(args) | PseudoClass::Dir(args) => {
                dest.write_char('(')?;
                for (i, arg) in args.iter().enumerate() {
                    if i > 0 {
                        dest.write_char(' ')?;
                    }
                    match arg {
                        LangArg::Value(v) => cssparser::serialize_identifier(v, dest)?,
                        LangArg::Star => dest.write_char('*')?,
                    }
                }
                dest.write_char(')')
            },
            _ => Ok(()),
        }
    }
}

impl NonTSPseudoClass for PseudoClass {
    type Impl = SelectrsImpl;

    fn is_active_or_hover(&self) -> bool {
        matches!(self, PseudoClass::Active | PseudoClass::Hover)
    }

    fn is_user_action_state(&self) -> bool {
        matches!(
            self,
            PseudoClass::Active | PseudoClass::Hover | PseudoClass::Focus
        )
    }
}

/// Uninhabited: `parse_pseudo_element` is left at its erroring default, so
/// `::before` etc. fail to parse — compatible with selectr, whose
/// translators error on pseudo-elements too ("Pseudo-elements are not
/// supported.", R/xpath.R:123-127).
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

    /// `:is()` and `:where()` map to selectr's Matching/Where classes.
    fn parse_is_and_where(&self) -> bool {
        true
    }

    /// selectr treats `:matches()` as an alias for `:is()`
    /// (R/parser.R:616-618).
    fn is_is_alias(&self, name: &str) -> bool {
        name.eq_ignore_ascii_case("matches")
    }

    /// `:has()` maps to selectr's Has class. The translator restricts the
    /// arguments to what selectr's parser accepts (compounds with the
    /// implied descendant combinator).
    fn parse_has(&self) -> bool {
        true
    }

    /// `:nth-child(an+b of S)` / `:nth-last-child(an+b of S)`,
    /// CSS Selectors Level 4.
    fn parse_nth_child_of(&self) -> bool {
        true
    }

    /// The non-tree-structural pseudo-classes selectr knows: its
    /// "never matches" set (R/xpath.R:898-909) plus the HTML-translator
    /// overrides. Anything else errors, matching selectr's
    /// "The pseudo-class :foo is unknown".
    fn parse_non_ts_pseudo_class(
        &self,
        location: SourceLocation,
        name: cssparser::CowRcStr<'i>,
    ) -> Result<PseudoClass, cssparser::ParseError<'i, Self::Error>> {
        let pc = match_ignore_ascii_case! { &name,
            "any-link" => PseudoClass::AnyLink,
            "link" => PseudoClass::Link,
            "visited" => PseudoClass::Visited,
            "hover" => PseudoClass::Hover,
            "active" => PseudoClass::Active,
            "focus" => PseudoClass::Focus,
            "target" => PseudoClass::Target,
            "target-within" => PseudoClass::TargetWithin,
            "local-link" => PseudoClass::LocalLink,
            "enabled" => PseudoClass::Enabled,
            "disabled" => PseudoClass::Disabled,
            "checked" => PseudoClass::Checked,
            _ => {
                return Err(location.new_custom_error(
                    SelectorParseErrorKind::UnsupportedPseudoClassOrElement(name),
                ));
            },
        };
        Ok(pc)
    }

    /// `:lang()` and `:dir()`, with selectr's argument grammar
    /// (R/parser.R:626-668): idents, strings, and `*` wildcards, separated
    /// by whitespace and/or commas (commas are pure separators — leading,
    /// trailing, and repeated commas are all tolerated). At least one
    /// argument is required. selectr additionally collects NUMBER/`+`/`-`
    /// tokens here only to reject them during translation; rejecting them
    /// at parse time errors on exactly the same selectors.
    ///
    /// `:contains()` — selectr's non-standard text-content pseudo — is
    /// deliberately unsupported and falls through to the rejection arm,
    /// as does any unknown functional pseudo.
    fn parse_non_ts_functional_pseudo_class<'t>(
        &self,
        name: cssparser::CowRcStr<'i>,
        parser: &mut CssParser<'i, 't>,
        _after_part: bool,
    ) -> Result<PseudoClass, cssparser::ParseError<'i, Self::Error>> {
        let is_lang = if name.eq_ignore_ascii_case("lang") {
            true
        } else if name.eq_ignore_ascii_case("dir") {
            false
        } else {
            return Err(parser.new_custom_error(
                SelectorParseErrorKind::UnsupportedPseudoClassOrElement(name),
            ));
        };

        let mut args = Vec::new();
        loop {
            let token = match parser.next() {
                Ok(t) => t.clone(),
                Err(_) => break, // end of the function's arguments
            };
            match token {
                Token::Ident(ref v) => args.push(LangArg::Value(v.as_ref().to_owned())),
                Token::QuotedString(ref v) => args.push(LangArg::Value(v.as_ref().to_owned())),
                Token::Delim('*') => args.push(LangArg::Star),
                Token::Comma => {},
                _ => {
                    return Err(parser.new_custom_error(
                        SelectorParseErrorKind::UnsupportedPseudoClassOrElement(name),
                    ));
                },
            }
        }
        if args.is_empty() {
            return Err(parser.new_custom_error(
                SelectorParseErrorKind::UnsupportedPseudoClassOrElement(name),
            ));
        }
        Ok(if is_lang {
            PseudoClass::Lang(args)
        } else {
            PseudoClass::Dir(args)
        })
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
