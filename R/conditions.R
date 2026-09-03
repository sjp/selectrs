# Every error selectrs signals is classed, so a caller can tell a
# malformed selector from a valid but untranslatable one from a bad
# argument. The base class is "selectrs_error"; the subclasses are
# "selectrs_parse_error" (fields selector, index, column),
# "selectrs_translation_error" (fields selector, index, construct, and
# column when the construct could be located) and
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
# failure, the element of a vectorised call that failed, and the position
# it failed at all survive the boundary. The list only holds the fields
# the failure actually has, and every one of them but the kind and the
# message becomes a field of the condition.
translationError <- function(failure) {
    class <- if (identical(failure$kind, "parse"))
        "selectrs_parse_error"
    else
        "selectrs_translation_error"
    selectrsError(failure$message, class,
                  failure[!names(failure) %in% c("kind", "message")])
}

# Bound a caller-supplied value echoed back in an error message, so that a
# very long one cannot push the rest of the message past
# options("warning.length"). The core bounds what it quotes from a selector
# the same way.
abbreviateValue <- function(value, limit = 40L) {
    if (nchar(value, type = "chars") <= limit)
        return(value)
    paste0(substr(value, 1L, limit), "...")
}
