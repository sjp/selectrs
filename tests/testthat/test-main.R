# We know that the results are correct via other tests, just check that
# this produces the correct results with respect to its arguments
test_that("css_to_xpath vectorises arguments", {
    expect_equal(css_to_xpath("a b"), "descendant-or-self::a//b")
    expect_equal(css_to_xpath("a b", prefix = ""), "a//b")
    expect_equal(css_to_xpath("a b", prefix = c("descendant-or-self::", "")), c("descendant-or-self::a//b", "a//b"))
    expect_equal(css_to_xpath("a:checked", prefix = "", translator = c("generic", "html", "xhtml")), c("a[(0)]", "a[((@selected and name(.) = 'option') or (@checked and (name(.) = 'input' or name(.) = 'command')and (@type = 'checkbox' or @type = 'radio')))]", "a[((@selected and name(.) = 'option') or (@checked and (name(.) = 'input' or name(.) = 'command')and (@type = 'checkbox' or @type = 'radio')))]"))
    expect_equal(css_to_xpath(c("a b", "b c"), prefix = ""), c("a//b", "b//c"))
})

test_that("css_to_xpath handles bad arguments", {
    # must have a selector arg provided
    expect_error(css_to_xpath(), "A valid selector (character vector) must be provided.", fixed = TRUE)
    expect_error(css_to_xpath(NULL), "A valid selector (character vector) must be provided.", fixed = TRUE)

    # should complain about incorrect vector type
    expect_error(css_to_xpath(1), "The 'selector' argument.*")
    expect_error(css_to_xpath("a", prefix = 1), "The 'prefix' argument.*")
    expect_error(css_to_xpath("a", translator = 1), "The 'translator' argument.*")

    # NAs error rather than silently shifting how arguments pair up
    expect_error(css_to_xpath(c("a", NA)),
                 "NA values are not allowed in the 'selector' argument")
    expect_error(css_to_xpath("a", prefix = c("", NA)),
                 "NA values are not allowed in the 'prefix' argument")
    expect_error(css_to_xpath("a", translator = c("generic", NA)),
                 "NA values are not allowed in the 'translator' argument")
    expect_error(css_to_xpath(NA_character_),
                 "NA values are not allowed in the 'selector' argument")
    expect_error(css_to_xpath("a", prefix = NA_character_),
                 "NA values are not allowed in the 'prefix' argument")
    expect_error(css_to_xpath("a", translator = NA_character_),
                 "NA values are not allowed in the 'translator' argument")
    expect_error(css_to_xpath(c("a", "b", "c"), prefix = c("p1//", NA, "p3//")),
                 "NA values are not allowed in the 'prefix' argument")

    # performs partial matching
    expect_equal(css_to_xpath("a", translator = "g"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = "gEnErIC"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = "h"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = "x"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = c("g", "h", "x")), rep("descendant-or-self::a", 3))

    # errors anything not matching generic, html, xhtml
    expect_error(css_to_xpath("a", translator = ""), "'arg' should be one of.*")
    expect_error(css_to_xpath("a", translator = "a"), "'arg' should be one of.*")
    expect_error(css_to_xpath("a", translator = c("generic", "a")), "'arg' should be one of.*")
})

test_that("namespace handling works correctly", {
    # formatNS must return a NULL or a named vector
    expect_equal(formatNS(NULL), NULL)
    expect_equal(formatNS(list(a = "b")), c(a = "b"))
    expect_equal(formatNS(c(a = "b")), c(a = "b"))

    # bad input handling
    expect_error(formatNS(1), "A namespace object must be.*")
    expect_error(formatNS(TRUE), "A namespace object must be.*")

    expect_error(formatNS("a"), "The namespace object either missing some or all names.*")
    expect_error(formatNS(c(a = "a", "b")), "The namespace object either missing some or all names.*")
    tmp <- letters
    names(tmp) <- letters[1:5]
    expect_error(formatNS(tmp), "The namespace object either missing some or all names.*")
    expect_error(formatNS(list(a = 1, b = 2)), "The values in the namespace object.*")

    # formatNSPrefix must return a pipe separated string of namespace prefixes
    expect_equal(formatNSPrefix(c(svg = "svg"), ""), "(//svg:*)/")
    expect_equal(formatNSPrefix(c(svg = "svg"), "asd"), "(//svg:*)/asd")
    expect_equal(formatNSPrefix(c(svg = "svg", math = "mathml"), ""), "(//svg:*|//math:*)/")
    expect_equal(formatNSPrefix(c(svg = "svg", math = "mathml"), "asd"), "(//svg:*|//math:*)/asd")
})
