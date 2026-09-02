#' Translate a CSS selector to an equivalent XPath expression
#'
#' This function maps a CSS selector to its XPath equivalent, which can then
#' be used to query XML documents. Selectors using constructs selectrs does
#' not support raise an error naming the construct.
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
#' @section Errors:
#' Errors raised by selectrs are classed conditions, so callers can tell
#' the kinds of failure apart without matching on the message. All of them
#' inherit from `selectrs_error`, and each carries the fields listed here:
#'
#' * `selectrs_parse_error` — the selector is not valid CSS. Fields
#'   `selector`, `index` (which element of a vectorised call failed) and
#'   `column`, the 1-based byte column the parse failed at.
#' * `selectrs_translation_error` — the selector is valid CSS but uses a
#'   construct that has no XPath 1.0 equivalent. Fields `selector`,
#'   `index` and `construct`.
#' * `selectrs_argument_error` — the arguments themselves are wrong (a
#'   non-character selector, an `NA`, an unknown translator).
#'
#' @param selector A character vector of CSS selectors.
#' @param prefix A character vector of prefixes to apply to the resulting
#'   XPath expressions. Not applied to selectors anchored by `:scope`.
#' @param translator A character vector of translators to use, each one of
#'   `"generic"`, `"html"`, or `"xhtml"`.
#' @returns A character vector of XPath expressions.
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

    translator <- sapply(translator, function(tran) {
        tryCatch(match.arg(tolower(tran), c("generic", "html", "xhtml")),
                 error = function(e) argumentError(conditionMessage(e)))
    })

    maxArgLength <- max(length(selector), length(prefix), length(translator))
    selector <- rep(selector, length.out = maxArgLength)
    prefix <- rep(prefix, length.out = maxArgLength)
    translator <- rep(translator, length.out = maxArgLength)

    # The core returns a character vector on success and a description of
    # the first untranslatable selector otherwise.
    xpath <- css_to_xpath_rust(selector, prefix, translator)
    if (!is.character(xpath))
        translationError(xpath)
    as.character(xpath)
}
