# Ported from selectr's tests/testthat/test-quoting.R (sjp/selectr@9ed9bb2,
# by Simon Potter), adapted for selectrs: testthat edition-3 idioms
# (expect_equal instead of expect_that/equals, no context()), the internal
# R6 translator replaced by css_to_xpath(), and the internal
# xpath_literal("") assertion dropped (its behavior is covered by the
# *[aval=""] translation below).

test_that("quote characters are escaped", {
    css <- function(x) css_to_xpath(x)

    expect_equal(css('*[aval="\'"]'),
                 'descendant-or-self::*[(@aval = "\'")]')
    expect_equal(css('*[aval="\'\'\'"]'),
                 "descendant-or-self::*[(@aval = \"'''\")]")
    expect_equal(css('*[aval=\'"\']'),
                 "descendant-or-self::*[(@aval = '\"')]")
    expect_equal(css('*[aval=\'"""\']'),
                 "descendant-or-self::*[(@aval = '\"\"\"')]")
    expect_equal(css('*[aval=\'"\\\'"\']'),
                 "descendant-or-self::*[(@aval = concat('\"',\"'\",'\"'))]")
})

test_that("empty attribute values are quoted", {
    css <- function(x) css_to_xpath(x)

    expect_equal(css('*[aval=""]'),
                 "descendant-or-self::*[(@aval = '')]")
    expect_equal(css('*[aval|=""]'),
                 paste0("descendant-or-self::*[(@aval and ",
                        "(@aval = '' or starts-with(@aval, '-')))]"))
    # These operators can never match an empty value
    expect_equal(css('*[aval~=""]'),
                 "descendant-or-self::*[(0)]")
    expect_equal(css('*[aval^=""]'),
                 "descendant-or-self::*[(0)]")
    expect_equal(css('*[aval$=""]'),
                 "descendant-or-self::*[(0)]")
    expect_equal(css('*[aval*=""]'),
                 "descendant-or-self::*[(0)]")
})
