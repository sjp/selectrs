\name{css_to_xpath}
\alias{css_to_xpath}
\title{
  Translate a CSS selector to an equivalent XPath expression
}
\description{
  This function aims to create an XPath expression equivalent to what
  would be matched by the given CSS selector. The reason the translation
  is required is because the XML and xml2 packages, being libxml2
  wrappers, can only evaluate XPath expressions.

  Using this function, it is possible to search an XML tree without the
  prerequisite of knowing XPath.
}
\usage{
css_to_xpath(selector,
             prefix = "descendant-or-self::",
             translator = "generic")
}
\arguments{
  \item{selector}{
    A character vector of CSS selectors.
  }
  \item{prefix}{
    A character vector of prefixes to apply to the resulting XPath
    expressions. Not applied to selectors anchored by \code{:scope}. A
    prefix is prepended verbatim and is never validated, so it has to
    end in an axis such as \code{"descendant-or-self::"} or a step
    separator such as \code{"//"}, or be \code{""}. Anything else
    quietly yields a different expression: \code{prefix = "/html/body "}
    turns \code{"div"} into \code{"/html/body div"}, which XPath reads
    as a division.
  }
  \item{translator}{
    A character vector of translators to use, each one of
    \code{"generic"}, \code{"html"}, or \code{"xhtml"}, matched on a
    unique prefix and case-insensitively over ASCII letters, so that the
    same names are accepted whatever the session's locale. See the
    Translators section.
  }
}
\details{
  See \code{\link{selectors}} for a table of every combinator, attribute
  operator and pseudo-class this function supports, along with an
  example translation for each; the rest of this section explains the
  reasoning behind the more surprising entries in that table.

  The three arguments are vectorised together: the result has the length
  of the longest of them, and an argument of length 1 is used for every
  element. Any other length must match that longest length exactly —
  unlike base R's arithmetic, a length that only partially fills the
  result is an error rather than a silent partial recycle.

  \code{selector} and \code{prefix} are translated to UTF-8 before they
  are used, so a string in any other encoding is read by its characters
  rather than by its bytes. Bytes that are not valid in the encoding the
  string claims cannot be translated, and are an error rather than a
  selector that silently loses them.

  The \code{:scope} pseudo-class refers to the node the resulting XPath
  expression is evaluated from: a selector starting with \code{:scope}
  is anchored on the \code{self::} axis (\code{":scope > a"} becomes
  \code{"self::*/a"}, the context node's \code{a} children) and the
  \code{prefix} is not applied to it. \code{:scope} is only supported in
  a selector's leftmost compound; anywhere else the context node cannot
  be expressed in XPath 1.0, so an error is raised.

  A type selector carrying no namespace prefix, such as \code{"p"},
  becomes an XPath name test and so matches elements in no namespace
  only. That is true wherever the name appears in the selector, so
  \code{":is(p)"}, \code{":not(p)"} and \code{":has(p)"} match exactly
  the elements \code{"p"} itself does. An element that is in a
  namespace, a default namespace declared with \code{xmlns} included,
  has to be selected through a prefix, as in \code{"d|p"}: prefixes are
  resolved through the namespace map supplied when the expression is
  evaluated (the \code{ns} argument of \code{\link[xml2]{xml_find_all}}
  or \code{\link[XML]{getNodeSet}}), not through the prefix spelled in
  the document. Two forms need no such map: \code{"*|p"} matches
  \code{p} in any namespace, and \code{"|p"} is the explicit spelling of
  \code{p} in no namespace.

  The of-type pseudo-classes (\code{:first-of-type},
  \code{:last-of-type}, \code{:nth-of-type()},
  \code{:nth-last-of-type()}, and \code{:only-of-type}) need an element
  type in the same compound to count siblings with:
  \code{"p:first-of-type"} translates, but \code{"*:first-of-type"}
  raises an error, as do selectors that leave the type implicit, like
  \code{".foo:first-of-type"}. XPath 1.0 cannot compare a sibling's name
  with the matched element's own name, so these have no translation.
  (selectr has the same limitation.) Note also that an any-namespace
  type like \code{"*|p:first-of-type"} counts same-typed siblings by
  \code{local-name()}, which groups same-named types from different
  namespaces together.

  The CSS Selectors Level 4 column combinator (\code{"col || td"}) and
  the grid-structural pseudo-classes \code{:nth-col()} and
  \code{:nth-last-col()} are not supported and raise an error: table
  column membership depends on \code{colspan}/\code{rowspan} layout
  arithmetic that an XPath 1.0 expression cannot perform.

  The \code{:empty} pseudo-class matches what browsers match: an element
  with any text content — even white space alone — is not empty, while
  comment nodes do not count as content. The Selectors Level 4 draft
  loosens \code{:empty} to also match white-space-only elements, but no
  browser engine has shipped that change, and selectrs (like selectr)
  deliberately keeps the implemented-everywhere behaviour.

  \code{:lang()} ranges are matched as RFC 4647 language ranges,
  wildcards included, quoted or not. A range naming a single subtag is a
  prefix test. Under the \code{html} and \code{xhtml} translators a
  range naming more than one subtag is approximated from the nearest
  language-attributed ancestor and may skip subtags, so
  \code{:lang(de-DE)} matches \code{lang="de-Latn-DE"}; the generic
  translator has only XPath's \code{lang()} function, which does
  Selectors 3 \code{|=}-style prefix matching, so there
  \code{:lang(de-DE)} matches a \code{de-DE} prefix only.

  A wildcard as the whole range (\code{:lang(*)}) matches any element
  whose content language is tagged at all, and one as the final subtag
  (\code{:lang(en-*)}) is the same test as \code{:lang(en)}; both work
  under every translator. Elsewhere in the range a wildcard needs RFC
  4647 extended filtering, which the \code{html} and \code{xhtml}
  translators do: a leading \code{*} stands for the tag's first subtag,
  so \code{:lang(*-CH)} matches \code{de-CH} and \code{fr-Latn-CH} but
  not \code{ch} itself, while a wildcard further in moves past nothing —
  every range subtag after the first is already searched for through the
  whole remaining tag — so \code{:lang(de-*-DE)} is the same test as
  \code{:lang(de-DE)}. XPath's \code{lang()} has nowhere to put the rest
  of a range it prefix-matches, so under the generic translator such a
  range is a translation error rather than a silent mis-match.

  Which attribute supplies that language differs by translator: the
  \code{html} translator reads \code{lang}, while the \code{xhtml}
  translator reads \code{xml:lang} or \code{lang}, preferring
  \code{xml:lang} where an element carries both, as the HTML language
  determination does. The generic translator uses XPath's \code{lang()}
  function, which is defined in terms of \code{xml:lang} alone. With the
  \code{html} and \code{xhtml} translators the language comes from the
  nearest ancestor-or-self that declares one.

  The \code{:dir()} pseudo-class never matches, in every translator: it
  selects by \emph{resolved} directionality, which requires runtime bidi
  resolution (\code{dir="auto"} first-strong-character detection,
  \code{bdi} defaults, and inheritance with invalid values skipped) that
  a static XPath expression cannot perform. An approximation walking to
  the nearest \code{dir} attribute is deliberately not attempted;
  selectr behaves the same way.

  The \code{html} and \code{xhtml} translators qualify a number of
  pseudo-classes — \code{:checked}, \code{:default}, \code{:disabled},
  \code{:enabled}, \code{:link}, \code{:optional},
  \code{:placeholder-shown}, \code{:read-only}, \code{:read-write} and
  \code{:required} — to apply only to the relevant (X)HTML elements,
  identified by local name regardless of namespace, so that
  \code{"*|input:disabled"} and \code{"d1|input:disabled"} apply
  \code{:disabled} exactly as \code{"input:disabled"} does on an
  unnamespaced HTML document. See \code{\link{selectors}} for exactly
  which elements and attributes each of these matches.
}
\value{
  A character vector of XPath expressions, one per element of the
  recycled arguments.
}
\section{Translators}{
  The \code{translator} argument chooses how names, and the
  pseudo-classes whose meaning depends on document semantics, are
  translated:
  \itemize{
    \item \code{"generic"} — plain CSS and XPath semantics: element and
    attribute names are matched case-sensitively, and no pseudo-class
    carries an HTML-specific meaning.
    \item \code{"html"} — lower-cases element and attribute names, as
    HTML parsing does, compares the values of the attributes HTML makes
    case-insensitive (\code{type}, \code{rel}, \code{lang}, …) without
    regard to case, and gives \code{:link}, \code{:any-link},
    \code{:checked}, \code{:default}, \code{:enabled}, \code{:disabled}
    (including HTML's \code{fieldset}/\code{legend} carve-out),
    \code{:required}, \code{:optional}, \code{:read-write},
    \code{:read-only}, \code{:placeholder-shown} and \code{:lang()}
    their static HTML meaning. Most of them are confined to the elements
    HTML defines them over, so a selector naming any other element never
    matches: \code{"a:enabled"} translates to \code{"a[0]"}. The
    exceptions are \code{:lang()} and the
    \code{:read-write}/\code{:read-only} pair, which every element
    answers.
    \item \code{"xhtml"} — the same pseudo-class meanings as
    \code{"html"}, but names and attribute values keep their case, XHTML
    being XML, and \code{:lang()} reads \code{xml:lang} in preference to
    \code{lang}.
  }

  The argument is matched case-insensitively and on a unique prefix, so
  \code{"g"}, \code{"H"} and \code{"xh"} name the \code{"generic"},
  \code{"html"} and \code{"xhtml"} translators.
}
\section{Supported selectors}{
  Every translator handles:
  \itemize{
    \item Type, universal (\code{*}) and namespaced (\code{"ns|e"},
    \code{"*|e"}, \code{"|e"}) selectors.
    \item ID (\code{"#id"}) and class (\code{".class"}) selectors.
    \item Attribute selectors — \code{[attr]}, \code{=}, \code{~=},
    \code{|=}, \code{^=}, \code{$=} and \code{*=} — with the Level 4
    \code{i} and \code{s} case-sensitivity flags.
    \item The descendant, child (\code{>}), next-sibling (\code{+}) and
    subsequent-sibling (\code{~}) combinators, and selector lists
    (\code{"a, b"}).
    \item The nth family — \code{:nth-child()},
    \code{:nth-last-child()}, \code{:nth-of-type()},
    \code{:nth-last-of-type()}, \code{:first-child}, \code{:last-child},
    \code{:first-of-type}, \code{:last-of-type}, \code{:only-child} and
    \code{:only-of-type} — including the Level 4 \code{An+B of S} form.
    \item \code{:is()} (and its legacy alias \code{:matches()}),
    \code{:where()}, \code{:not()} and \code{:has()}, with complex,
    combinator-bearing arguments and with a leading combinator inside
    \code{:has()} (\code{"e:has(> .foo)"}).
    \item \code{:scope}, \code{:root}, \code{:empty} and \code{:lang()}.
  }

  The pseudo-classes whose meaning rests on user or runtime state that a
  static document does not have are parsed but never match, translating
  to the always-false predicate \code{[0]}: \code{:hover},
  \code{:active}, \code{:focus}, \code{:focus-within},
  \code{:focus-visible}, \code{:visited}, \code{:target},
  \code{:target-within}, \code{:local-link} and \code{:dir()}, plus —
  under the \code{"generic"} translator, which has no HTML semantics to
  give them — \code{:link}, \code{:any-link}, \code{:checked},
  \code{:default}, \code{:enabled}, \code{:disabled}, \code{:required},
  \code{:optional}, \code{:read-write}, \code{:read-only} and
  \code{:placeholder-shown}.

  Everything else is an error rather than an approximation:
  \itemize{
    \item Pseudo-elements (\code{"::before"}, \code{"::slotted()"},
    \code{"::part()"}).
    \item The column combinator and \code{:nth-col()} /
    \code{:nth-last-col()}, and the of-type pseudo-classes without an
    element type to count with, as described above.
    \item The non-standard \code{[attr!=value]} and \code{:contains()}.
    \item Any other pseudo-class, including the form pseudo-classes
    \code{:valid}, \code{:in-range} and \code{:indeterminate}, whose
    meaning no static translation can reach, so that a typo stays loud
    instead of silently matching nothing.
    \item \code{:host}, the \code{&} nesting selector, and a
    \code{:has()} nested inside another \code{:has()}.
    \item \code{:scope} outside the leftmost compound, or inside a
    functional pseudo-class such as \code{":is(:scope)"}.
  }

  Three fixed limits apply to selectors that are otherwise translatable,
  and exceeding one raises a translation error naming it. Functional
  pseudo-classes — \code{:is()}, \code{:not()}, \code{:where()},
  \code{:has()} and the \code{of S} argument of the nth family — may
  nest 32 levels deep; an \code{An+B of S} list may nest 8 levels deep;
  and one \code{of S} list may translate to at most 1 MiB of XPath. The
  \code{of S} limits are the tighter pair because XPath 1.0 has no
  variables: \code{S} has to be written out once to filter the siblings
  being counted and again to constrain the element matched, so the
  output doubles per level. No hand-written selector comes near any of
  the three, but a generated one — a \code{:not()} per excluded class,
  say — can. selectr has no fixed limit of this kind: it recurses in R,
  so how deep a selector it accepts depends on
  \code{getOption("expressions")} and on the stack the call is made
  from.
}
\section{Errors}{
  Errors raised by selectrs are classed conditions, so callers can tell
  the kinds of failure apart without matching on the message. All of
  them inherit from \code{selectrs_error}, and each carries the fields
  listed here:
  \itemize{
    \item \code{selectrs_parse_error} — the selector is not valid CSS.
    Fields \code{selector}, \code{index} (which element of a vectorised
    call failed) and \code{column}, the 1-based character column of the
    token the message names.
    \item \code{selectrs_translation_error} — the selector is valid CSS
    but uses a construct that has no XPath 1.0 equivalent. Fields
    \code{selector}, \code{index}, \code{construct}, and \code{column}
    when the construct could be located in the selector. Some constructs
    are only recognised once the selector has been parsed, and those
    have no \code{column}.
    \item \code{selectrs_argument_error} — the arguments themselves are
    wrong (a non-character selector, an \code{NA}, a selector or prefix
    that is not valid in its declared encoding, an unknown translator,
    lengths that do not recycle).
  }

  The \code{selector} field holds the UTF-8 translation of the element
  that failed, which is the string that was actually translated, not the
  caller's original object.

  Which of the first two classes a given failure raises follows the CSS
  grammar: a selector is a parse error when the grammar cannot read it,
  and a translation error when it parses and then has no XPath. An
  unknown or unsupported pseudo-class or pseudo-element is a translation
  error — a misspelling such as \code{"a:first_child"}, an unrecognised
  name such as \code{"e:frobnicate"}, a pseudo-element
  (\code{"::before"}), and \code{":contains()"}, \code{":nth-col()"},
  \code{":nth-last-col()"} and \code{":host"} — even though this
  package's parser, unlike selectr's, knows the supported names and
  stops there. A \emph{functional} pseudo-element (\code{"::slotted(x)"},
  \code{"a::part(b)"}, and the legacy single-colon \code{"a:before(x)"})
  is the exception, and a parse error: no grammar admits it. So are the
  column combinator (\code{"col || td"}) and the \code{&} nesting
  selector. A caller that catches \code{selectrs_error}, or that treats
  the two subclasses alike, sees no difference.

  Every one of these classes is signalled under its selectr name as well
  - \code{selectr_parse_error}, \code{selectr_translation_error},
  \code{selectr_argument_error} and \code{selectr_error} - so a handler,
  \code{inherits()} test or \code{expect_error(class = )} written
  against selectr fires here unchanged. The selectrs names come first,
  so \code{class(e)[1]} and the printed header still name the package
  that raised the error.

  selectr's names for two of the fields are carried alongside the ones
  above, for the same reason: \code{pos} on any condition that has a
  \code{column} (the same number, as the double selectr's is), and
  \code{feature} on a translation error. \code{column}, \code{index}
  and \code{construct} are the primary names. \code{feature} holds
  selectr's short token for the construct — \code{":frobnicate"},
  \code{"::before"}, \code{":lang()"}, \code{":scope"},
  \code{"*:first-of-type"} — so a handler that switches on it keeps
  working; \code{construct} holds the longer phrase the message reads
  as. A construct selectr has no token for, such as one of the three
  translation limits above, has no token here either, and its
  \code{feature} is the phrase.
}
\references{
  CSS Selectors Level 4 \url{https://www.w3.org/TR/selectors-4/}, XPath
  \url{https://www.w3.org/TR/xpath/}.
}
\author{
  Simon Potter
}
\seealso{
  \code{\link{selectors}} for the full selector-support reference;
  \code{\link{querySelectorAll}}, which propagates the same conditions.
}
\examples{
  css_to_xpath(".testclass")
  css_to_xpath("#testid", prefix = "")
  css_to_xpath("#testid .testclass")
  css_to_xpath(":scope > .testclass")
  css_to_xpath(":checked", translator = "html")

  # Every condition is signalled under both packages' class names (see
  # the Errors section), so either handler below catches this selector.
  tryCatch(
    css_to_xpath("div >"),
    selectrs_parse_error = function(e) {
      cat(conditionMessage(e), "\n")
      cat("Column:", e$column, "\n")
    }
  )
  tryCatch(
    css_to_xpath("div >"),
    selectr_parse_error = function(e) cat("Position:", e$pos, "\n")
  )
}
