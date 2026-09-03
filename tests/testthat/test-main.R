test_that("the Rust core is reachable and reports the css-to-xpath crate version", {
    core <- selectrs:::selectrs_core_version()
    expect_type(core, "character")
    expect_length(core, 1L)
    expect_false(is.na(core))
    expect_true(nzchar(core))
    # version should be parseable as a numeric_version
    expect_no_error(numeric_version(core))
})

test_that("the Rust boundary itself rejects NA values", {
    # css_to_xpath() validates first; calling the internal function
    # directly must not translate NA as the literal element 'NA'
    expect_error(selectrs:::css_to_xpath_rust(NA_character_, "", "generic"),
                 "`selectors` must not contain NA values")
    expect_error(selectrs:::css_to_xpath_rust("a", NA_character_, "generic"),
                 "`prefixes` must not contain NA values")
    expect_error(selectrs:::css_to_xpath_rust("a", "", NA_character_),
                 "`translators` must not contain NA values")
})

# We know that the results are correct via other tests, just check that
# this produces the correct results with respect to its arguments
test_that("css_to_xpath vectorises arguments", {
    expect_equal(css_to_xpath("a b"), "descendant-or-self::a//b")
    expect_equal(css_to_xpath("a b", prefix = ""), "a//b")
    expect_equal(css_to_xpath("a b", prefix = c("descendant-or-self::", "")), c("descendant-or-self::a//b", "a//b"))
    # @type comparisons fold case (HTML enumerated attribute); shared by
    # the html and xhtml translators.
    t_lc <- paste0("translate(@type, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', ",
                   "'abcdefghijklmnopqrstuvwxyz')")
    checked_html <- paste0("input[@checked and (", t_lc, " = 'checkbox' or ",
                           t_lc, " = 'radio')]")
    expect_equal(css_to_xpath("input:checked", prefix = "", translator = c("generic", "html", "xhtml")), c("input[0]", checked_html, checked_html))
    expect_equal(css_to_xpath(c("a b", "b c"), prefix = ""), c("a//b", "b//c"))

    # repeated selectors translate once and reuse the result; a repeat is
    # only a cache hit when the prefix and translator also match
    expect_equal(css_to_xpath(c("#a", "#b", "#a")),
                 c(css_to_xpath("#a"), css_to_xpath("#b"), css_to_xpath("#a")))
    expect_equal(css_to_xpath("#a", prefix = c("//", "", "//")),
                 c("//*[@id = 'a']", "*[@id = 'a']", "//*[@id = 'a']"))
    expect_equal(css_to_xpath("A", prefix = "", translator = c("html", "generic", "html")),
                 c("a", "A", "a"))
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

test_that("css_to_xpath rejects lengths that only partially recycle", {
    # a length that does not fill the result is a call-site mistake, not
    # a request to recycle
    expect_error(css_to_xpath(c("a", "b"), prefix = c("", "", "//")),
                 "must each have length 1 or 3, but the following argument does not: selector (length 2)",
                 fixed = TRUE)
    expect_error(css_to_xpath(c("a", "b", "c"), prefix = c("", "//")),
                 "must each have length 1 or 3, but the following argument does not: prefix (length 2)",
                 fixed = TRUE)
    expect_error(css_to_xpath(c("a", "b", "c", "d"), translator = c("html", "generic")),
                 "the following argument does not: translator (length 2)",
                 fixed = TRUE)
    expect_error(css_to_xpath(c("a", "b"), prefix = c("", "//", "///"),
                              translator = c("html", "generic")),
                 "the following arguments do not: selector (length 2), translator (length 2)",
                 fixed = TRUE)
    expect_true(inherits(tryCatch(css_to_xpath(c("a", "b"), prefix = c("", "", "//")),
                                  error = identity),
                         "selectrs_argument_error"))

    # length-1 arguments still broadcast, and equal lengths still pair up
    expect_equal(css_to_xpath(c("a", "b"), prefix = "//"), c("//a", "//b"))
    expect_equal(css_to_xpath("a", prefix = c("//", "")), c("//a", "a"))
    expect_equal(css_to_xpath(c("a", "b"), prefix = c("//", "")), c("//a", "b"))
})

test_that("namespace handling works correctly", {
    # formatNS must return a NULL or a named vector
    expect_equal(formatNS(NULL), NULL)
    expect_equal(formatNS(list(a = "b")), c(a = "b"))
    expect_equal(formatNS(c(a = "b")), c(a = "b"))

    # bad input handling
    expect_error(formatNS(1), "A namespace object must be.*")
    expect_error(formatNS(TRUE), "A namespace object must be.*")

    expect_error(formatNS("a"), "The namespace object is missing some or all names.*")
    expect_error(formatNS(c(a = "a", "b")), "The namespace object is missing some or all names.*")
    tmp <- letters
    names(tmp) <- letters[1:5]
    expect_error(formatNS(tmp), "The namespace object is missing some or all names.*")
    expect_error(formatNS(list(a = 1, b = 2)), "The values in the namespace object.*")

    # list elements must each be a single string: a longer (or empty)
    # element would misalign every subsequent prefix after unlist()
    expect_error(formatNS(list(a = c("u1", "u2"), b = "u3")),
                 "Each element in the namespace object must be a single character string.")
    expect_error(formatNS(list(a = character(0), b = "u3")),
                 "Each element in the namespace object must be a single character string.")
    expect_equal(formatNS(list(a = "u1", b = "u3")), c(a = "u1", b = "u3"))

    # a missing or empty URI would reach XML::getNodeSet()/xml2 as a namespace
    # definition, giving a confusing error or a silent non-match
    expect_error(formatNS(list(a = NA_character_)),
                 "The namespace URIs must be non-missing, non-empty character strings.")
    expect_error(formatNS(c(a = NA_character_)),
                 "The namespace URIs must be non-missing, non-empty character strings.")
    expect_error(formatNS(c(a = "")),
                 "The namespace URIs must be non-missing, non-empty character strings.")
    expect_error(formatNS(list(a = "urn:a", b = "")),
                 "The namespace URIs must be non-missing, non-empty character strings.")
    expect_equal(formatNS(c(a = "urn:a")), c(a = "urn:a"))

    # formatNSPrefix must return a pipe separated string of namespace prefixes
    expect_equal(formatNSPrefix(c(svg = "svg"), ""), "(descendant-or-self::svg:*)/")
    expect_equal(formatNSPrefix(c(svg = "svg"), "asd"), "(descendant-or-self::svg:*)/asd")
    expect_equal(formatNSPrefix(c(svg = "svg", math = "mathml"), ""),
                 "(descendant-or-self::svg:*|descendant-or-self::math:*)/")
    expect_equal(formatNSPrefix(c(svg = "svg", math = "mathml"), "asd"),
                 "(descendant-or-self::svg:*|descendant-or-self::math:*)/asd")
})

test_that("a panic in the Rust core surfaces as a catchable R error", {
    # The release profile sets panic = "unwind" so that a panic reachable
    # from arbitrary user CSS becomes an R error rather than killing the
    # session; selectrs_panic_test() exists to exercise that path.
    # (savvy reports the panic and its location on stderr, and raises this)
    expect_error(selectrs:::selectrs_panic_test(), "panic happened")
    # and the session carries on afterwards
    expect_equal(css_to_xpath("a", prefix = ""), "a")
})
