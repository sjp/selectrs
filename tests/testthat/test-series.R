test_that("series are parsed case-insensitively", {
    xpath <- function(css) css_to_xpath(paste0("e:nth-child(", css, ")"))

    expect_equal(xpath("2N"), xpath("2n"))
    expect_equal(xpath("ODD"), xpath("odd"))
    expect_equal(xpath("EVEN"), xpath("even"))
    expect_equal(xpath("Odd"), xpath("odd"))
    expect_equal(xpath("eVen"), xpath("even"))
    expect_equal(xpath("N"), xpath("n"))
    expect_equal(xpath("N+1"), xpath("n+1"))
    expect_equal(xpath("-N+3"), xpath("-n+3"))
    expect_equal(xpath("2N+1"), xpath("2n+1"))
    expect_equal(css_to_xpath("e:nth-last-of-type(2N)"),
                 css_to_xpath("e:nth-last-of-type(2n)"))

    # Genuinely invalid input must still error
    expect_error(css_to_xpath("e:nth-child(2x)"))
    expect_error(css_to_xpath("e:nth-child(odds)"))
    expect_error(css_to_xpath("e:nth-child(m+1)"))
})

test_that("whitespace is only permitted around the sign before B", {
    # spec-legal placements keep working
    expect_equal(css_to_xpath("e:nth-child(2n + 1)"),
                 css_to_xpath("e:nth-child(2n+1)"))
    expect_equal(css_to_xpath("e:nth-child(2n +1)"),
                 css_to_xpath("e:nth-child(2n+1)"))
    expect_equal(css_to_xpath("e:nth-child(n+ 1)"),
                 css_to_xpath("e:nth-child(n+1)"))
    expect_equal(css_to_xpath("e:nth-child( 2n+1 )"),
                 css_to_xpath("e:nth-child(2n+1)"))
    # whitespace anywhere else is invalid (css-syntax-3 An+B grammar)
    expect_error(css_to_xpath("e:nth-child(3 7)"))
    expect_error(css_to_xpath("e:nth-child(2 n)"))
    expect_error(css_to_xpath("e:nth-child(2n 1)"))
    expect_error(css_to_xpath("e:nth-child(2n+1 3)"))
    expect_error(css_to_xpath("e:nth-child(2 n + 1)"))
    expect_error(css_to_xpath("e:nth-child(- n)"))
    expect_error(css_to_xpath("e:nth-child(+ 2n)"))
    expect_error(css_to_xpath("e:nth-child(o dd)"))
})

test_that("non-integer A and B values are rejected", {
    # An+B takes <integer> values only; these must not be truncated
    expect_error(css_to_xpath("e:nth-child(2.5)"))
    expect_error(css_to_xpath("e:nth-child(1.9)"))
    expect_error(css_to_xpath("e:nth-child(2e1)"))
    expect_error(css_to_xpath("e:nth-child(2.5n+1)"))
    expect_error(css_to_xpath("e:nth-child(2n+1.5)"))
    # signed integers and leading zeros remain valid
    expect_equal(css_to_xpath("e:nth-child(+05)"),
                 css_to_xpath("e:nth-child(5)"))
})
