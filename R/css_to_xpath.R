#' Translate a CSS selector to an equivalent XPath expression
#'
#' This function maps a CSS selector to its XPath equivalent, which can then
#' be used to query XML documents. Selectors using constructs selectrs does
#' not support raise an error naming the construct.
#'
#' Argument validation and recycling happen in R; the translation itself is
#' one vectorized call into the Rust core.
#'
#' @param selector A character vector of CSS selectors.
#' @param prefix A character vector of prefixes to apply to the resulting
#'   XPath expressions.
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

    if (anyNA(selector)) {
        warning("NA values were found in the 'selector' argument, they have been removed")
        selector <- selector[!is.na(selector)]
    }

    if (anyNA(prefix)) {
        warning("NA values were found in the 'prefix' argument, they have been removed")
        prefix <- prefix[!is.na(prefix)]
    }

    if (anyNA(translator)) {
        warning("NA values were found in the 'translator' argument, they have been removed")
        translator <- translator[!is.na(translator)]
    }

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
