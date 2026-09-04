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

    # errors anything not matching generic, html, xhtml, naming the
    # argument and echoing the value that was rejected
    expect_error(css_to_xpath("a", translator = ""),
                 "'translator' must be one of .*, not \"\"")
    expect_error(css_to_xpath("a", translator = "a"),
                 "'translator' must be one of .*, not \"a\"")
    expect_error(css_to_xpath("a", translator = c("generic", "a")),
                 "'translator' must be one of .*, not \"a\"")

    # the value is echoed as it is matched, in lower case
    expect_error(css_to_xpath("a", translator = "XmL"),
                 "not \"xml\"$")

    # every distinct bad value is named at once, in the order they were
    # written, so fixing one does not just surface the next
    expect_error(css_to_xpath(c("a", "b", "c", "d"),
                              translator = c("xml", "json", "xml", "generic")),
                 "not \"xml\", \"json\"$")

    # the value is echoed whole, however long it is
    expect_error(css_to_xpath("a", translator = strrep("x", 100)),
                 paste0("not \"", strrep("x", 100), "\""), fixed = TRUE)
})

test_that("css_to_xpath reads arguments by their characters, not their bytes", {
    latin1 <- iconv('[title="café"]', "UTF-8", "latin1")
    expect_equal(Encoding(latin1), "latin1")
    expect_equal(css_to_xpath(latin1, prefix = ""), "*[@title = 'café']")

    # the prefix is translated as well, and both come back as UTF-8
    prefix <- iconv("//café//", "UTF-8", "latin1")
    xpath <- css_to_xpath("a", prefix = prefix)
    expect_equal(xpath, "//café//a")
    expect_equal(Encoding(xpath), "UTF-8")

    # a "bytes" string carries no encoding to translate from, but its
    # bytes are read as UTF-8 and are unambiguous when they are valid
    bytes <- '[title="café"]'
    Encoding(bytes) <- "bytes"
    expect_equal(css_to_xpath(bytes, prefix = ""), "*[@title = 'café']")
})

test_that("css_to_xpath rejects bytes that are invalid in their encoding", {
    # in a non-UTF-8 locale enc2utf8() translates the unmarked strings
    # below from the native encoding, and they are valid there
    skip_if_not(l10n_info()[["UTF-8"]])

    invalid <- '[title="\xff\xfe"]'
    expect_equal(Encoding(invalid), "unknown")
    expect_error(css_to_xpath(invalid),
                 "The 'selector' argument contains invalid or non-convertible bytes",
                 fixed = TRUE)
    expect_true(inherits(tryCatch(css_to_xpath(invalid), error = identity),
                         "selectrs_argument_error"))

    # a mark that the bytes do not live up to is caught as well: enc2utf8()
    # believes it and passes the string through untouched
    lying <- invalid
    Encoding(lying) <- "UTF-8"
    expect_error(css_to_xpath(lying),
                 "The 'selector' argument contains invalid or non-convertible bytes",
                 fixed = TRUE)
    marked <- invalid
    Encoding(marked) <- "bytes"
    expect_error(css_to_xpath(marked),
                 "The 'selector' argument contains invalid or non-convertible bytes",
                 fixed = TRUE)

    # only one element of a vectorised argument need be invalid
    expect_error(css_to_xpath(c("a", invalid)),
                 "The 'selector' argument contains invalid or non-convertible bytes",
                 fixed = TRUE)

    # an invalid prefix would otherwise vanish, leaving a plausible
    # expression that means something else
    expect_error(css_to_xpath("a", prefix = "pre\xff::"),
                 "The 'prefix' argument contains invalid or non-convertible bytes",
                 fixed = TRUE)
})

test_that("css_to_xpath rejects lengths that only partially recycle", {
    # a length that does not fill the result is a call-site mistake, not
    # a request to recycle
    expect_error(css_to_xpath(c("a", "b"), prefix = c("", "", "//")),
                 "length 1 or a common length (3), which the following argument do not: selector (length 2)",
                 fixed = TRUE)
    expect_error(css_to_xpath(c("a", "b", "c"), prefix = c("", "//")),
                 "length 1 or a common length (3), which the following argument do not: prefix (length 2)",
                 fixed = TRUE)
    expect_error(css_to_xpath(c("a", "b", "c", "d"), translator = c("html", "generic")),
                 "which the following argument do not: translator (length 2)",
                 fixed = TRUE)
    expect_error(css_to_xpath(c("a", "b"), prefix = c("", "//", "///"),
                              translator = c("html", "generic")),
                 "which the following arguments do not: selector (length 2), translator (length 2)",
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

    expect_error(formatNS("a"), "every element needs a non-empty name\\.")
    expect_error(formatNS(c(a = "a", "b")), "every element needs a non-empty name\\.")
    tmp <- letters
    names(tmp) <- letters[1:5]
    expect_error(formatNS(tmp), "every element needs a non-empty name\\.")
    expect_error(formatNS(list(a = 1, b = 2)), "The values in the namespace object.*")

    # list elements must each be a single string: a longer (or empty)
    # element would misalign every subsequent prefix after unlist()
    expect_error(formatNS(list(a = c("u1", "u2"), b = "u3")),
                 "Each element in the namespace object must be a single character string.")
    expect_error(formatNS(list(a = character(0), b = "u3")),
                 "Each element in the namespace object must be a single character string.")
    expect_equal(formatNS(list(a = "u1", b = "u3")), c(a = "u1", b = "u3"))

    # an object wrong in more than one way is reported by name and by prefix
    # before it is reported by element length
    expect_error(formatNS(list(c("u1", "u2"))),
                 "every element needs a non-empty name\\.")
    expect_error(formatNS(list("1x" = c("u1", "u2"))),
                 "not '1x').", fixed = TRUE)

    # a missing or empty URI would reach XML::getNodeSet()/xml2 as a namespace
    # definition, giving a confusing error or a silent non-match
    expect_error(formatNS(list(a = NA_character_)),
                 "The values in the namespace object must be non-missing, non-empty strings.")
    expect_error(formatNS(c(a = NA_character_)),
                 "The values in the namespace object must be non-missing, non-empty strings.")
    expect_error(formatNS(c(a = "")),
                 "The values in the namespace object must be non-missing, non-empty strings.")
    expect_error(formatNS(list(a = "urn:a", b = "")),
                 "The values in the namespace object must be non-missing, non-empty strings.")
    expect_equal(formatNS(c(a = "urn:a")), c(a = "urn:a"))

    # a prefix that is not an XML name would splice into the generated
    # XPath and come back as a libxml2 syntax error instead
    expect_error(formatNS(c("a b" = "urn:a")),
                 "not 'a b').", fixed = TRUE)
    expect_error(formatNS(list("x:y" = "urn:a")),
                 "not 'x:y').", fixed = TRUE)
    # only the first offending prefix is named, as in selectr
    expect_error(formatNS(c("1a" = "urn:a", "-b" = "urn:b")),
                 "not '1a').", fixed = TRUE)
    expect_error(formatNS(c("a/b" = "urn:a")),
                 "not 'a/b').", fixed = TRUE)
    # libxml2 accepts a non-ASCII prefix, so the check must not be ASCII-only
    expect_equal(formatNS(c("\u00e9l" = "urn:a")), c("\u00e9l" = "urn:a"))
    expect_equal(formatNS(c("\u65e5\u672c" = "urn:a")),
                 c("\u65e5\u672c" = "urn:a"))
    # a middle dot and a combining mark may follow the first character of
    # an XML name, though neither may be it
    expect_equal(formatNS(c("a\u00b7b" = "urn:a")), c("a\u00b7b" = "urn:a"))
    expect_equal(formatNS(c("a\u0301" = "urn:a")), c("a\u0301" = "urn:a"))
    expect_error(formatNS(c("\u00b7a" = "urn:a")), "not '\u00b7a').", fixed = TRUE)
    # U+00AA is a letter to Unicode but not to XML 1.0, and libxml2 goes
    # by XML 1.0: an argument error here, rather than a syntax error from
    # inside a query, is the whole point of asking the core
    expect_error(formatNS(c("\u00aa" = "urn:a")), "not '\u00aa').", fixed = TRUE)

    # `ns` names and the prefixes written in a selector are judged by one
    # rule, so a prefix the map admits is one a query can then use
    prefixes <- c("svg", "_x", "\u00e9l", "\u65e5\u672c", "a\u00b7b", "a\u0301",
                  "\u2126", "\u00aa", "\u01c5", "\u0242", "\uff21", "1a")
    admitted <- vapply(prefixes, function(prefix) {
        ns <- structure("urn:a", names = prefix)
        !inherits(tryCatch(formatNS(ns), error = identity), "error")
    }, logical(1))
    translated <- vapply(prefixes, function(prefix) {
        selector <- paste0(prefix, "|a")
        !inherits(tryCatch(css_to_xpath(selector), error = identity), "error")
    }, logical(1))
    expect_equal(admitted, translated)
    expect_true(admitted[["svg"]])
    expect_false(admitted[["\u00aa"]])

    # a prefix marked latin1 reaches the core as UTF-8, not as the ""
    # its bytes would otherwise become; one whose declared bytes cannot
    # be converted at all is no more a name than what it was written as
    latin1 <- "\xe9l"
    Encoding(latin1) <- "latin1"
    expect_equal(unname(formatNS(structure("urn:a", names = latin1))), "urn:a")
    expect_equal(names(formatNS(structure("urn:a", names = latin1))), "\u00e9l")
    expect_error(formatNS(structure("urn:a", names = "\xe9l")),
                 "not '<e9>l').", fixed = TRUE)
    # the names xml_ns() produces, and the ones a document is likely to
    # declare, must all pass
    expect_equal(formatNS(c(d1 = "urn:a", "svg" = "urn:b", "_x" = "urn:c",
                           "x.y-z" = "urn:d")),
                 c(d1 = "urn:a", svg = "urn:b", "_x" = "urn:c",
                   "x.y-z" = "urn:d"))

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
