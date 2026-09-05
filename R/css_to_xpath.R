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
    bad <- unique(asciiLower(distinct[is.na(matched)]))
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

# The choices are ASCII, so fold A-Z and nothing else. tolower() folds by
# the session's locale and maps every letter it knows, so a name spelled
# with a dotted capital I would select "generic" in a UTF-8 locale but be
# rejected under C.
asciiLower <- function(x) {
    chartr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", x)
}

# match.arg()'s semantics -- case-insensitive, a unique prefix accepted --
# without its message, which names its own formal 'arg' rather than the
# argument the user wrote. pmatch() returns NA for an unknown name, for an
# ambiguous prefix and for "", which is exactly what match.arg() rejects;
# the caller collects the NAs so that every bad value is named at once.
matchTranslator <- function(name) {
    translatorChoices[pmatch(asciiLower(name), translatorChoices)]
}
