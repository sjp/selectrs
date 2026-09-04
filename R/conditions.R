# Every error selectrs signals is classed, so a caller can tell a
# malformed selector from a valid but untranslatable one from a bad
# argument. The base class is "selectrs_error"; the subclasses are
# "selectrs_parse_error" (fields selector, index, column),
# "selectrs_translation_error" (fields selector, index, construct, and
# column when the construct could be located) and
# "selectrs_argument_error".
#
# Each of those is signalled under the matching selectr name as well, and
# the two fields selectr names differently are carried under both names,
# so that a handler, an inherits() test or an expect_error(class = )
# written against selectr keeps working here. The selectrs names come
# first, so class(e)[1] and the printed header still say which package
# raised it.
#
# The call is dropped from every condition: for the querySelector*
# generics it would name the method rather than the function the user
# wrote, and for a translation failure the useful context is the selector,
# which the condition carries as a field.

selectrsError <- function(message, class, fields = list()) {
    alias <- sub("^selectrs_", "selectr_", class)
    stop(do.call(errorCondition,
                 c(list(message,
                        class = c(class, alias, "selectrs_error",
                                  "selectr_error"),
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
    fields <- failure[!names(failure) %in% c("kind", "message")]
    # selectr names the same two values "pos" and "feature", so a handler
    # reading either finds it here. "pos" is "column" as the double
    # selectr's is, so identical() against a literal holds. The core
    # supplies "feature" wherever selectr has a short token for the
    # construct; where it has none, the phrase the message reads as
    # stands in.
    if (!is.null(fields$column))
        fields$pos <- as.double(fields$column)
    if (is.null(fields$feature) && !is.null(fields$construct))
        fields$feature <- fields$construct
    selectrsError(failure$message, class, fields)
}
