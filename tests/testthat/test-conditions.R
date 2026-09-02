test_that("a syntax error is a selectrs_parse_error carrying the column", {
    e <- tryCatch(css_to_xpath("div >"), error = identity)
    expect_identical(class(e), c("selectrs_parse_error", "selectrs_error",
                                 "error", "condition"))
    expect_equal(e$selector, "div >")
    expect_equal(e$index, 1L)
    expect_equal(e$column, 6L)
    expect_null(e$construct)
    expect_null(conditionCall(e))
    # the caret block is still part of the message
    expect_match(conditionMessage(e), "Unable to parse the CSS selector \"div >\"",
                 fixed = TRUE)
})

test_that("an unsupported construct is a selectrs_translation_error naming it", {
    e <- tryCatch(css_to_xpath("*:first-of-type"), error = identity)
    expect_identical(class(e), c("selectrs_translation_error", "selectrs_error",
                                 "error", "condition"))
    expect_equal(e$selector, "*:first-of-type")
    expect_equal(e$index, 1L)
    expect_equal(e$construct, "an of-type pseudo-class on the universal selector `*`")
    expect_null(e$column)
    expect_null(conditionCall(e))
    expect_match(conditionMessage(e), e$construct, fixed = TRUE)
})

test_that("the two translation failures are distinguishable from each other", {
    kind <- function(selector) {
        tryCatch(css_to_xpath(selector),
                 selectrs_parse_error = function(e) "parse",
                 selectrs_translation_error = function(e) "translation",
                 selectrs_argument_error = function(e) "argument",
                 error = function(e) "plain")
    }
    expect_equal(kind("div >"), "parse")
    expect_equal(kind("*:first-of-type"), "translation")
    expect_equal(kind(NA_character_), "argument")
})

test_that("a vectorised call reports which element failed", {
    e <- tryCatch(css_to_xpath(c("a", "div >", "b")), error = identity)
    expect_equal(e$index, 2L)
    expect_equal(e$selector, "div >")

    e <- tryCatch(css_to_xpath(c("a", "b", "*:first-of-type")), error = identity)
    expect_equal(e$index, 3L)

    # the failing element is found after recycling, not before it
    e <- tryCatch(css_to_xpath("div >", prefix = c("", "//")), error = identity)
    expect_equal(e$index, 1L)
})

test_that("argument errors from css_to_xpath are selectrs_argument_errors", {
    classed <- function(expr) {
        e <- tryCatch(expr, error = identity)
        identical(class(e), c("selectrs_argument_error", "selectrs_error",
                              "error", "condition"))
    }
    expect_true(classed(css_to_xpath()))
    expect_true(classed(css_to_xpath(NULL)))
    expect_true(classed(css_to_xpath(1)))
    expect_true(classed(css_to_xpath("a", prefix = 1)))
    expect_true(classed(css_to_xpath("a", translator = 1)))
    expect_true(classed(css_to_xpath(NA_character_)))
    expect_true(classed(css_to_xpath(character(0))))
    expect_true(classed(css_to_xpath("a", translator = "nosuch")))

    # match.arg()'s own wording is kept, only the class and call change
    e <- tryCatch(css_to_xpath("a", translator = "nosuch"), error = identity)
    expect_match(conditionMessage(e), "'arg' should be one of")
    expect_null(conditionCall(e))
})

test_that("argument errors from the query functions are classed too", {
    argumentClass <- c("selectrs_argument_error", "selectrs_error", "error",
                       "condition")
    expectArgumentError <- function(expr) {
        e <- tryCatch(expr, error = identity)
        expect_identical(class(e), argumentClass)
    }
    expectArgumentError(querySelector(1, "a"))
    expectArgumentError(querySelectorAll(1, "a"))
    expectArgumentError(querySelectorNS(1, "a", c(a = "u")))
    expectArgumentError(querySelectorAllNS(1, "a", c(a = "u")))
    expectArgumentError(validateSelector(c("a", "b")))
    expectArgumentError(formatNS(1))
})

test_that("a failing selector reaching the query functions keeps its class", {
    skip_if_not_installed("xml2")
    doc <- xml2::read_xml("<a><b/></a>")
    e <- tryCatch(querySelector(doc, "div >"), error = identity)
    expect_identical(class(e), c("selectrs_parse_error", "selectrs_error",
                                 "error", "condition"))
    e <- tryCatch(querySelectorAll(doc, "*:first-of-type"), error = identity)
    expect_identical(class(e), c("selectrs_translation_error", "selectrs_error",
                                 "error", "condition"))
})

test_that("the Rust boundary reports a failure rather than throwing", {
    # css_to_xpath() turns this list into a condition; the internal
    # function itself returns it, so a translation failure is not an
    # unwind across the FFI boundary
    failure <- selectrs:::css_to_xpath_rust("div >", "", "generic")
    expect_type(failure, "list")
    expect_equal(failure$kind, "parse")
    expect_equal(failure$column, 6L)
    expect_equal(failure$index, 1L)

    failure <- selectrs:::css_to_xpath_rust("*:first-of-type", "", "generic")
    expect_equal(failure$kind, "unsupported")
    expect_type(failure$construct, "character")
})
