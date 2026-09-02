# Every error selectrs signals is classed, so a caller can tell a
# malformed selector from a valid but untranslatable one from a bad
# argument. The base class is "selectrs_error"; the subclasses are
# "selectrs_parse_error" (fields selector, index, column),
# "selectrs_translation_error" (fields selector, index, construct) and
# "selectrs_argument_error".
#
# The call is dropped from every condition: for the querySelector*
# generics it would name the method rather than the function the user
# wrote, and for a translation failure the useful context is the selector,
# which the condition carries as a field.

selectrsError <- function(message, class, fields = list()) {
    stop(do.call(errorCondition,
                 c(list(message, class = c(class, "selectrs_error"),
                        call = NULL),
                   fields)))
}

argumentError <- function(message) {
    selectrsError(message, "selectrs_argument_error")
}

# Raise the condition for a failure the Rust core reported. The core hands
# the failure back as a named list rather than throwing, so the kind of
# failure, the element of a vectorised call that failed, and the parse
# error column all survive the boundary.
translationError <- function(failure) {
    class <- if (identical(failure$kind, "parse"))
        "selectrs_parse_error"
    else
        "selectrs_translation_error"
    selectrsError(failure$message, class,
                  failure[!names(failure) %in% c("kind", "message")])
}
