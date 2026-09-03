#' Translate a CSS selector to an equivalent XPath expression
#'
#' This function maps a CSS selector to its XPath equivalent, which can then
#' be used to query XML documents. Selectors using constructs selectrs does
#' not support raise an error naming the construct.
#'
#' See \code{\link{selectors}} for a table of every combinator, attribute operator and
#' pseudo-class this function supports, along with an example translation
#' for each; the rest of this section explains the reasoning behind the more
#' surprising entries in that table.
#'
#' The three arguments are vectorised together: the result has the length
#' of the longest of them, and an argument of length 1 is used for every
#' element. Any other length must match that longest length exactly —
#' unlike base R's arithmetic, a length that only partially fills the
#' result is an error rather than a silent partial recycle.
#'
#' `selector` and `prefix` are translated to UTF-8 before they are used,
#' so a string in any other encoding is read by its characters rather
#' than by its bytes. Bytes that are not valid in the encoding the string
#' claims cannot be translated, and are an error rather than a selector
#' that silently loses them.
#'
#' The `:scope` pseudo-class refers to the node the resulting XPath
#' expression is evaluated from: a selector starting with `:scope` is
#' anchored on the `self::` axis (`":scope > a"` becomes `"self::*/a"`,
#' the context node's `a` children) and the `prefix` is not applied to it.
#' `:scope` is only supported in a selector's leftmost compound; anywhere
#' else the context node cannot be expressed in XPath 1.0, so an error is
#' raised.
#'
#' A type selector carrying no namespace prefix, such as `"p"`, becomes an
#' XPath name test and so matches elements in no namespace only. That is
#' true wherever the name appears in the selector, so `":is(p)"`,
#' `":not(p)"` and `":has(p)"` match exactly the elements `"p"` itself
#' does. An element that is in a namespace, a default namespace declared
#' with `xmlns` included, has to be selected through a prefix, as in
#' `"d|p"`: prefixes are resolved through the namespace map supplied when
#' the expression is evaluated (the `ns` argument of
#' [xml2::xml_find_all()] or [XML::getNodeSet()]), not through the prefix
#' spelled in the document. Two forms need no such map: `"*|p"` matches
#' `p` in any namespace, and `"|p"` is the explicit spelling of `p` in no
#' namespace.
#'
#' The of-type pseudo-classes (`:first-of-type`, `:last-of-type`,
#' `:nth-of-type()`, `:nth-last-of-type()`, and `:only-of-type`) need an
#' element type in the same compound to count siblings with:
#' `"p:first-of-type"` translates, but `"*:first-of-type"` raises an
#' error, as do selectors that leave the type implicit, like
#' `".foo:first-of-type"`. XPath 1.0 cannot compare a sibling's name with
#' the matched element's own name, so these have no translation. (selectr
#' has the same limitation.) Note also that an any-namespace type like
#' `"*|p:first-of-type"` counts same-typed siblings by `local-name()`,
#' which groups same-named types from different namespaces together.
#'
#' The CSS Selectors Level 4 column combinator (`"col || td"`) and the
#' grid-structural pseudo-classes `:nth-col()` and `:nth-last-col()` are
#' not supported and raise an error: table column membership depends on
#' `colspan`/`rowspan` layout arithmetic that an XPath 1.0 expression
#' cannot perform.
#'
#' The `:empty` pseudo-class matches what browsers match: an element with
#' any text content — even white space alone — is not empty, while
#' comment nodes do not count as content. The Selectors Level 4 draft
#' loosens `:empty` to also match white-space-only elements, but no
#' browser engine has shipped that change, and selectrs (like selectr)
#' deliberately keeps the implemented-everywhere behaviour.
#'
#' `:lang()` ranges are matched as RFC 4647 language ranges, with a
#' restriction on where the wildcard may appear: it is accepted as a
#' whole range (`:lang(*)`, matching any element whose content language
#' is tagged at all) or as the final subtag (`:lang(en-*)`, the same test
#' as `:lang(en)`), quoted or not. A wildcard anywhere else
#' (`:lang(*-CH)`, `:lang(de-*-DE)`) would need RFC 4647 extended
#' filtering, which is not implemented, and raises a translation error
#' with every translator rather than silently mis-matching. A range
#' naming a single subtag is a prefix test. Under the `html` and `xhtml`
#' translators a range naming more than one subtag is approximated from
#' the nearest language-attributed ancestor and may skip subtags, so
#' `:lang(de-DE)` matches `lang="de-Latn-DE"`; the generic translator has
#' only XPath's `lang()` function, which does Selectors 3 `|=`-style
#' prefix matching, so there `:lang(de-DE)` matches a `de-DE` prefix
#' only.
#'
#' Which attribute supplies that language differs by translator: the
#' `html` translator reads `lang`, while the `xhtml` translator reads
#' `xml:lang` or `lang`, preferring `xml:lang` where an element carries
#' both, as the HTML language determination does. The generic translator
#' uses XPath's `lang()` function, which is defined in terms of
#' `xml:lang` alone. With the `html` and `xhtml` translators the language
#' comes from the nearest ancestor-or-self that declares one.
#'
#' The `:dir()` pseudo-class never matches, in every translator: it
#' selects by *resolved* directionality, which requires runtime bidi
#' resolution (`dir="auto"` first-strong-character detection, `bdi`
#' defaults, and inheritance with invalid values skipped) that a static
#' XPath expression cannot perform. An approximation walking to the
#' nearest `dir` attribute is deliberately not attempted; selectr behaves
#' the same way.
#'
#' The `html` and `xhtml` translators qualify a number of pseudo-classes
#' — `:checked`, `:default`, `:disabled`, `:enabled`, `:link`,
#' `:optional`, `:placeholder-shown`, `:read-only`, `:read-write` and
#' `:required` — to apply only to the relevant (X)HTML elements,
#' identified by local name regardless of namespace, so that
#' `"*|input:disabled"` and `"d1|input:disabled"` apply `:disabled`
#' exactly as `"input:disabled"` does on an unnamespaced HTML document.
#' See \code{\link{selectors}} for exactly which elements and attributes each of
#' these matches.
#'
#' @section Translators:
#' The `translator` argument chooses how names, and the pseudo-classes
#' whose meaning depends on document semantics, are translated:
#'
#' * `"generic"` — plain CSS and XPath semantics: element and attribute
#'   names are matched case-sensitively, and no pseudo-class carries an
#'   HTML-specific meaning.
#' * `"html"` — lower-cases element and attribute names, as HTML parsing
#'   does, compares the values of the attributes HTML makes
#'   case-insensitive (`type`, `rel`, `lang`, …) without regard to case,
#'   and gives `:link`, `:any-link`, `:checked`, `:default`, `:enabled`,
#'   `:disabled` (including HTML's `fieldset`/`legend` carve-out),
#'   `:required`, `:optional`, `:read-write`, `:read-only`,
#'   `:placeholder-shown` and `:lang()` their static HTML meaning. Most
#'   of them are confined to the elements HTML defines them over, so a
#'   selector naming any other element never matches: `"a:enabled"`
#'   translates to `"a[0]"`. The exceptions are `:lang()` and the
#'   `:read-write`/`:read-only` pair, which every element answers.
#' * `"xhtml"` — the same pseudo-class meanings as `"html"`, but names
#'   and attribute values keep their case, XHTML being XML, and `:lang()`
#'   reads `xml:lang` in preference to `lang`.
#'
#' The argument is matched case-insensitively and on a unique prefix, so
#' `"g"`, `"H"` and `"xh"` name the `"generic"`, `"html"` and `"xhtml"`
#' translators.
#'
#' @section Supported selectors:
#' Every translator handles:
#'
#' * Type, universal (`*`) and namespaced (`"ns|e"`, `"*|e"`, `"|e"`)
#'   selectors.
#' * ID (`"#id"`) and class (`".class"`) selectors.
#' * Attribute selectors — `[attr]`, `=`, `~=`, `|=`, `^=`, `$=` and
#'   `*=` — with the Level 4 `i` and `s` case-sensitivity flags.
#' * The descendant, child (`>`), next-sibling (`+`) and
#'   subsequent-sibling (`~`) combinators, and selector lists
#'   (`"a, b"`).
#' * The nth family — `:nth-child()`, `:nth-last-child()`,
#'   `:nth-of-type()`, `:nth-last-of-type()`, `:first-child`,
#'   `:last-child`, `:first-of-type`, `:last-of-type`, `:only-child`
#'   and `:only-of-type` — including the Level 4 `An+B of S` form.
#' * `:is()` (and its legacy alias `:matches()`), `:where()`, `:not()`
#'   and `:has()`, with complex, combinator-bearing arguments and with a
#'   leading combinator inside `:has()` (`"e:has(> .foo)"`).
#' * `:scope`, `:root`, `:empty` and `:lang()`.
#'
#' The pseudo-classes whose meaning rests on user or runtime state that
#' a static document does not have are parsed but never match,
#' translating to the always-false predicate `[0]`: `:hover`, `:active`,
#' `:focus`, `:focus-within`, `:focus-visible`, `:visited`, `:target`,
#' `:target-within`, `:local-link` and `:dir()`, plus — under the
#' `"generic"` translator, which has no HTML semantics to give them —
#' `:link`, `:any-link`, `:checked`, `:default`, `:enabled`,
#' `:disabled`, `:required`, `:optional`, `:read-write`, `:read-only`
#' and `:placeholder-shown`.
#'
#' Everything else is an error rather than an approximation:
#'
#' * Pseudo-elements (`"::before"`, `"::slotted()"`, `"::part()"`).
#' * The column combinator and `:nth-col()` / `:nth-last-col()`, and the
#'   of-type pseudo-classes without an element type to count with, as
#'   described above.
#' * The non-standard `[attr!=value]` and `:contains()`.
#' * Any other pseudo-class, including the form pseudo-classes `:valid`,
#'   `:in-range` and `:indeterminate`, whose meaning no static
#'   translation can reach, so that a typo stays loud instead of
#'   silently matching nothing.
#' * `:host`, the `&` nesting selector, and a `:has()` nested inside
#'   another `:has()`.
#' * `:scope` outside the leftmost compound, or inside a functional
#'   pseudo-class such as `":is(:scope)"`.
#'
#' @section Errors:
#' Errors raised by selectrs are classed conditions, so callers can tell
#' the kinds of failure apart without matching on the message. All of them
#' inherit from `selectrs_error`, and each carries the fields listed here:
#'
#' * `selectrs_parse_error` — the selector is not valid CSS. Fields
#'   `selector`, `index` (which element of a vectorised call failed) and
#'   `column`, the 1-based character column the parse failed at.
#' * `selectrs_translation_error` — the selector is valid CSS but uses a
#'   construct that has no XPath 1.0 equivalent. Fields `selector`,
#'   `index`, `construct`, and `column` when the construct could be
#'   located in the selector. Some constructs are only recognised once
#'   the selector has been parsed, and those have no `column`.
#' * `selectrs_argument_error` — the arguments themselves are wrong (a
#'   non-character selector, an `NA`, a selector or prefix that is not
#'   valid in its declared encoding, an unknown translator, lengths that
#'   do not recycle).
#'
#' The `selector` field holds the UTF-8 translation of the element that
#' failed, which is the string that was actually translated, not the
#' caller's original object.
#'
#' Every one of these classes is signalled under its selectr name as
#' well - `selectr_parse_error`, `selectr_translation_error`,
#' `selectr_argument_error` and `selectr_error` - so a handler,
#' `inherits()` test or `expect_error(class = )` written against selectr
#' fires here unchanged. The selectrs names come first, so `class(e)[1]`
#' and the printed header still name the package that raised the error.
#'
#' selectr's names for two of the fields are carried alongside the ones
#' above, for the same reason: `pos` on any condition that has a `column`
#' (the same number), and `feature` on a translation error (the same
#' string as `construct`). `column`, `index` and `construct` are the
#' primary names. Note that `feature`'s *value* is not the one selectr
#' would give — selectr names the construct with a short token such as
#' `":scope"`, where selectrs describes it in a phrase — so a handler
#' that compares `feature` to a literal needs rewriting even though one
#' that prints it does not.
#'
#' @param selector A character vector of CSS selectors.
#' @param prefix A character vector of prefixes to apply to the resulting
#'   XPath expressions. Not applied to selectors anchored by `:scope`. A
#'   prefix is prepended verbatim and is never validated, so it has to end
#'   in an axis such as `"descendant-or-self::"` or a step separator such
#'   as `"//"`, or be `""`. Anything else quietly yields a different
#'   expression: `prefix = "/html/body "` turns `"div"` into
#'   `"/html/body div"`, which XPath reads as a division.
#' @param translator A character vector of translators to use, each one of
#'   `"generic"`, `"html"`, or `"xhtml"`, matched case-insensitively and
#'   on a unique prefix. See the Translators section.
#' @returns A character vector of XPath expressions, one per element of
#'   the recycled arguments.
#' @references CSS Selectors Level 4 <https://www.w3.org/TR/selectors-4/>,
#'   XPath <https://www.w3.org/TR/xpath/>.
#' @author Simon Potter
#' @seealso \code{\link{selectors}} for the full selector-support reference;
#'   [querySelectorAll()], which propagates the same conditions.
#' @examples
#' css_to_xpath(".testclass")
#' css_to_xpath("#testid", prefix = "")
#' css_to_xpath("#testid .testclass")
#' css_to_xpath(":scope > .testclass")
#' css_to_xpath(":checked", translator = "html")
#'
#' # Every condition is signalled under both packages' class names (see
#' # the Errors section), so either handler below catches this selector.
#' tryCatch(
#'   css_to_xpath("div >"),
#'   selectrs_parse_error = function(e) {
#'     cat(conditionMessage(e), "\n")
#'     cat("Column:", e$column, "\n")
#'   }
#' )
#' tryCatch(
#'   css_to_xpath("div >"),
#'   selectr_parse_error = function(e) cat("Position:", e$pos, "\n")
#' )
#' @export
css_to_xpath <- function(selector, prefix = "descendant-or-self::", translator = "generic") {
    if (missing(selector) || is.null(selector))
        argumentError("A valid selector (character vector) must be provided.")

    if (!is.character(selector))
        argumentError("The 'selector' argument must be a character vector")
    if (!is.character(prefix))
        argumentError("The 'prefix' argument must be a character vector")
    if (!is.character(translator))
        argumentError("The 'translator' argument must be a character vector")

    if (anyNA(selector))
        argumentError("NA values are not allowed in the 'selector' argument")
    if (anyNA(prefix))
        argumentError("NA values are not allowed in the 'prefix' argument")
    if (anyNA(translator))
        argumentError("NA values are not allowed in the 'translator' argument")

    # The core reads a string as raw bytes and requires UTF-8, so a
    # latin1-marked selector would otherwise reach it as "". Translating
    # here makes the caller's encoding mark irrelevant. What enc2utf8()
    # cannot fix is a string whose bytes are invalid in the encoding it
    # claims: it is passed through untouched and would reach the core as
    # "", so it is rejected instead.
    selector <- enc2utf8(selector)
    prefix <- enc2utf8(prefix)
    if (!all(validUTF8(selector)))
        argumentError("The 'selector' argument contains invalid or non-convertible bytes")
    if (!all(validUTF8(prefix)))
        argumentError("The 'prefix' argument contains invalid or non-convertible bytes")

    zeroLengthArgs <- character(0)
    if (!length(selector))
        zeroLengthArgs <- c(zeroLengthArgs, "selector")
    if (!length(prefix))
        zeroLengthArgs <- c(zeroLengthArgs, "prefix")
    if (!length(translator))
        zeroLengthArgs <- c(zeroLengthArgs, "translator")

    if (length(zeroLengthArgs)) {
        plural <- if (length(zeroLengthArgs) > 1) "s" else ""
        argumentError(paste0("Zero length character vector found for the ",
                             "following argument", plural, ": ",
                             paste0(zeroLengthArgs, collapse = ", ")))
    }

    # Matching once per distinct value: the work is identical for repeats,
    # and a long translator vector rarely holds more than the three names.
    distinct <- unique(unname(translator))
    matched <- vapply(distinct, matchTranslator, character(1), USE.NAMES = FALSE)
    bad <- unique(tolower(distinct[is.na(matched)]))
    if (length(bad))
        argumentError(paste0("'translator' must be one of \"",
                             paste0(translatorChoices, collapse = "\", \""),
                             "\", not \"", paste0(bad, collapse = "\", \""),
                             "\""))
    translator <- matched[match(translator, distinct)]

    argLengths <- c(selector = length(selector), prefix = length(prefix),
                    translator = length(translator))
    maxArgLength <- max(argLengths)
    # Only length-1 arguments broadcast: partial recycling would pair
    # arguments up in a way the caller is unlikely to have meant.
    badArgs <- names(argLengths)[argLengths != 1L & argLengths != maxArgLength]
    if (length(badArgs)) {
        plural <- if (length(badArgs) > 1) "s" else ""
        argumentError(paste0("Arguments must have length 1 or a common length (",
                             maxArgLength, "), which the following argument",
                             plural, " do not: ",
                             paste0(badArgs, " (length ", argLengths[badArgs],
                                    ")", collapse = ", ")))
    }

    selector <- rep(selector, length.out = maxArgLength)
    prefix <- rep(prefix, length.out = maxArgLength)
    translator <- rep(translator, length.out = maxArgLength)

    # The core returns a character vector on success and a description of
    # the first untranslatable selector otherwise.
    xpath <- css_to_xpath_rust(selector, prefix, translator)
    if (!is.character(xpath))
        translationError(xpath)
    xpath
}

translatorChoices <- c("generic", "html", "xhtml")

# match.arg()'s semantics -- case-insensitive, a unique prefix accepted --
# without its message, which names its own formal 'arg' rather than the
# argument the user wrote. pmatch() returns NA for an unknown name, for an
# ambiguous prefix and for "", which is exactly what match.arg() rejects;
# the caller collects the NAs so that every bad value is named at once.
matchTranslator <- function(name) {
    translatorChoices[pmatch(tolower(name), translatorChoices)]
}
