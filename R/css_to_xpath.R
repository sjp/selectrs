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
        stop("A valid selector (character vector) must be provided.")

    if (!is.character(selector))
        stop("The 'selector' argument must be a character vector")
    if (!is.character(prefix))
        stop("The 'prefix' argument must be a character vector")
    if (!is.character(translator))
        stop("The 'translator' argument must be a character vector")

    if (anyNA(selector))
        stop("NA values are not allowed in the 'selector' argument")
    if (anyNA(prefix))
        stop("NA values are not allowed in the 'prefix' argument")
    if (anyNA(translator))
        stop("NA values are not allowed in the 'translator' argument")

    zeroLengthArgs <- character(0)
    if (!length(selector))
        zeroLengthArgs <- c(zeroLengthArgs, "selector")
    if (!length(prefix))
        zeroLengthArgs <- c(zeroLengthArgs, "prefix")
    if (!length(translator))
        zeroLengthArgs <- c(zeroLengthArgs, "translator")

    if (length(zeroLengthArgs)) {
        plural <- if (length(zeroLengthArgs) > 1) "s" else ""
        stop("Zero length character vector found for the following argument",
             plural,
             ": ",
             paste0(zeroLengthArgs, collapse = ", "))
    }

    translator <- sapply(translator, function(tran) {
        match.arg(tolower(tran), c("generic", "html", "xhtml"))
    })

    maxArgLength <- max(length(selector), length(prefix), length(translator))
    selector <- rep(selector, length.out = maxArgLength)
    prefix <- rep(prefix, length.out = maxArgLength)
    translator <- rep(translator, length.out = maxArgLength)

    as.character(css_to_xpath_rust(selector, prefix, translator))
}
