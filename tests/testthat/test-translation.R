xpath <- function(css) {
    css_to_xpath(css, prefix = "")
}

test_that("translation of CSS to XPath occurs and threads through its arguments", {
    # Full translation correctness is the css-to-xpath crate's own test
    # suite; these just confirm selectrs calls into it and that each
    # argument (selector, prefix, translator) reaches the crate.
    expect_equal(xpath("e"), "e")
    expect_equal(xpath('e[foo="bar"]'), "e[@foo = 'bar']")
    expect_equal(xpath("e.warning"),
                 "e[contains(concat(' ', normalize-space(@class), ' '), ' warning ')]")
    expect_equal(xpath("e#myid"), "e[@id = 'myid']")
    expect_equal(xpath("e > f"), "e/f")
    expect_equal(xpath("e:first-child"),
                 "e[count(preceding-sibling::*) = 0]")
    expect_equal(xpath("div:has(p)"), "div[.//p]")
    expect_equal(xpath("div:is(p, span)"), "div[self::p or self::span]")
    expect_equal(xpath("*|e"), "*[local-name() = 'e']")

    # 'prefix' threads through
    expect_equal(css_to_xpath("a b"), "descendant-or-self::a//b")
    expect_equal(css_to_xpath("a b", prefix = ""), "a//b")

    # 'translator' threads through
    expect_equal(css_to_xpath("input:checked", prefix = ""), "input[0]")
    expect_false(identical(css_to_xpath("input:checked", prefix = "", translator = "html"),
                           "input[0]"))

    # invalid selectors propagate as R errors
    expect_error(css_to_xpath("div > "))
})
