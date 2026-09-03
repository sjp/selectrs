#' Translate a CSS selector to an equivalent XPath expression
#'
#' This function maps a CSS selector to its XPath equivalent, which can then
#' be used to query XML documents. Selectors using constructs selectrs does
#' not support raise an error naming the construct.
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
#' The `:empty` pseudo-class matches what browsers match: an element with
#' any text content — even white space alone — is not empty, while
#' comment nodes do not count as content. The Selectors Level 4 draft
#' loosens `:empty` to also match white-space-only elements, but no
#' browser engine has shipped that change, and selectrs (like selectr)
#' deliberately keeps the implemented-everywhere behaviour.
#'
#' The `:dir()` pseudo-class never matches, in every translator: it
#' selects by *resolved* directionality, which requires runtime bidi
#' resolution (`dir="auto"` first-strong-character detection, `bdi`
#' defaults, and inheritance with invalid values skipped) that a static
#' XPath expression cannot perform. An approximation walking to the
#' nearest `dir` attribute is deliberately not attempted; selectr behaves
#' the same way.
#'
#' The CSS Selectors Level 4 column combinator (`"col || td"`) and the
#' grid-structural pseudo-classes `:nth-col()` and `:nth-last-col()` are
#' not supported and raise an error: table column membership depends on
#' `colspan`/`rowspan` layout arithmetic that an XPath 1.0 expression
#' cannot perform.
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
#' The message text is not part of the interface. Several of these
#' messages are worded differently from selectr's for the same failure,
#' and a long value the message echoes back is abbreviated where selectr
#' repeats it in full. The classes and the fields are what to match on.
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
#' @examples
#' css_to_xpath("#testid > .testclass")
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
    bad <- distinct[is.na(matched)]
    if (length(bad))
        argumentError(sprintf(
            paste0("The 'translator' argument must be one of \"generic\", ",
                   "\"html\" or \"xhtml\" (a unique prefix, in any case, is ",
                   "accepted), not %s"),
            paste0("\"", vapply(bad, abbreviateValue, "", USE.NAMES = FALSE),
                   "\"", collapse = ", ")))
    translator <- matched[match(translator, distinct)]

    argLengths <- c(selector = length(selector), prefix = length(prefix),
                    translator = length(translator))
    maxArgLength <- max(argLengths)
    # Only length-1 arguments broadcast: partial recycling would pair
    # arguments up in a way the caller is unlikely to have meant.
    badArgs <- names(argLengths)[argLengths != 1L & argLengths != maxArgLength]
    if (length(badArgs)) {
        offenders <- if (length(badArgs) > 1)
            "the following arguments do not"
        else
            "the following argument does not"
        argumentError(paste0("The 'selector', 'prefix' and 'translator' ",
                             "arguments must each have length 1 or ",
                             maxArgLength, ", but ", offenders, ": ",
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
