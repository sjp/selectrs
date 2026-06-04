# Ported from selectr's tests/testthat/test-translation.R
# (sjp/selectr@717e2ee, by Simon Potter). Expected XPath strings are
# byte-identical to selectr's output. Cases exercising constructs selectrs
# does not support ([a!=b], attribute case flags) are rewritten to assert
# an error, per the parity invariant in MIGRATION.md.
#
# Phase 1 scope: simple selectors (type/`*`, `#id`, `.class`, attribute
# operators, the four combinators, namespaces). Pseudo-classes and
# :nth-child() land in Phase 2 alongside the rest of the suite.

xpath <- function(css) {
    css_to_xpath(css, prefix = "")
}

test_that("translation of simple selectors to XPath works", {
    expect_equal(xpath("*"), "*")
    expect_equal(xpath("e"), "e")
    expect_equal(xpath("*|e"), "*[(local-name() = 'e')]")
    expect_equal(xpath("|e"), "e")
    expect_equal(xpath("|*"), "*[(namespace-uri() = '')]")
    expect_equal(xpath("*|*"), "*")
    expect_equal(xpath("e|f"), "e:f")
    expect_equal(xpath("svg|*"), "svg:*")
    expect_equal(xpath("e[foo]"), "e[(@foo)]")
    expect_equal(xpath("e[foo|bar]"), "e[(@foo:bar)]")
    expect_equal(xpath("[*|foo]"), "*[(@*[local-name() = 'foo'])]")
    expect_equal(xpath("[|foo]"), "*[(@foo)]")
    expect_equal(xpath('e[foo="bar"]'), "e[(@foo = 'bar')]")
    expect_equal(xpath('e[foo=""]'), "e[(@foo = '')]")
    expect_equal(xpath('e[foo|=""]'),
                 "e[(@foo and (@foo = '' or starts-with(@foo, '-')))]")
    expect_equal(xpath("e[foo='(test)']"), "e[(@foo = '(test)')]")
    expect_equal(xpath('e[foo="(test)"]'), "e[(@foo = '(test)')]")
    expect_equal(xpath("e[foo='(abc)']"), "e[(@foo = '(abc)')]")
    expect_equal(xpath("e[foo='(e2e)']"), "e[(@foo = '(e2e)')]")
    expect_equal(xpath('e[foo="(e2e)"]'), "e[(@foo = '(e2e)')]")
    expect_equal(xpath("e[foo='(123)']"), "e[(@foo = '(123)')]")
    expect_equal(xpath("e[foo='(12345)']"), "e[(@foo = '(12345)')]")
    # Six hex digits (max for CSS unicode escape)
    expect_equal(xpath("e[foo='(abcdef)']"), "e[(@foo = '(abcdef)')]")
    expect_equal(xpath("e[foo='(123456)']"), "e[(@foo = '(123456)')]")
    # Seven hex digits (exceeds max, so not unicode escape required)
    expect_equal(xpath("e[foo='(1234567)']"), "e[(@foo = '(1234567)')]")
    expect_equal(xpath("e[foo='(AbCdEf)']"), "e[(@foo = '(AbCdEf)')]")
    expect_equal(xpath("e[foo='(E2E)']"), "e[(@foo = '(E2E)')]")
    expect_equal(xpath("e[foo='(o2o)']"), "e[(@foo = '(o2o)')]")
    expect_equal(xpath('e[foo="(o2o)"]'), "e[(@foo = '(o2o)')]")
    expect_equal(xpath("e[foo='(xyz)']"), "e[(@foo = '(xyz)')]")
    expect_equal(xpath("e[foo='(test123)']"), "e[(@foo = '(test123)')]")
    expect_equal(xpath("e[foo='(abc)(def)']"), "e[(@foo = '(abc)(def)')]")
    expect_equal(xpath("e[foo='(abc )']"), "e[(@foo = '(abc )')]")
    expect_equal(xpath('e[foo~="bar"]'),
                 "e[(@foo and contains(concat(' ', normalize-space(@foo), ' '), ' bar '))]")
    expect_equal(xpath('e[foo^="bar"]'),
                 "e[(@foo and starts-with(@foo, 'bar'))]")
    expect_equal(xpath('e[foo$="bar"]'),
                 "e[(@foo and substring(@foo, string-length(@foo)-2) = 'bar')]")
    expect_equal(xpath('e[foo*="bar"]'),
                 "e[(@foo and contains(@foo, 'bar'))]")
    expect_equal(xpath('e[hreflang|="en"]'),
                 "e[(@hreflang and (@hreflang = 'en' or starts-with(@hreflang, 'en-')))]")
    # CSS Selectors Level 4 case-sensitivity flags
    lower_foo <- paste0("translate(@foo, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',",
                        " 'abcdefghijklmnopqrstuvwxyz')")
    expect_equal(xpath('e[foo="Bar" i]'),
                 paste0("e[(", lower_foo, " = 'bar')]"))
    expect_equal(xpath('e[foo^="Bar" i]'),
                 paste0("e[(", lower_foo, " and starts-with(",
                        lower_foo, ", 'bar'))]"))
    expect_equal(xpath('e[foo$="Bar" i]'),
                 paste0("e[(", lower_foo, " and substring(",
                        lower_foo, ", string-length(",
                        lower_foo, ")-2) = 'bar')]"))
    expect_equal(xpath('e[foo*="Bar" i]'),
                 paste0("e[(", lower_foo, " and contains(",
                        lower_foo, ", 'bar'))]"))
    expect_equal(xpath('e[foo~="Bar" i]'),
                 paste0("e[(", lower_foo,
                        " and contains(concat(' ', normalize-space(",
                        lower_foo, "), ' '), ' bar '))]"))
    expect_equal(xpath('e[foo|="Bar" i]'),
                 paste0("e[(", lower_foo, " and (",
                        lower_foo, " = 'bar' or starts-with(",
                        lower_foo, ", 'bar-')))]"))
    # The 'i' flag is ASCII case-insensitive: non-ASCII characters such
    # as 'É' are left alone
    expect_equal(xpath("e[foo='\\C9 x' i]"),
                 paste0("e[(", lower_foo, " = '\uC9x')]"))
    # An empty value cannot differ by case, so it keeps the exact
    # (existence-preserving) translation
    expect_equal(xpath('e[foo="" i]'), "e[(@foo = '')]")
    # The 's' flag requests the default case-sensitive matching
    expect_equal(xpath('e[foo="Bar" s]'), "e[(@foo = 'Bar')]")
    expect_equal(xpath('e[foo^="Bar" s]'),
                 "e[(@foo and starts-with(@foo, 'Bar'))]")
    expect_equal(xpath('e.warning'),
                 "e[(@class and contains(concat(' ', normalize-space(@class), ' '), ' warning '))]")
    expect_equal(xpath('e#myid'),
                 "e[(@id = 'myid')]")
    expect_equal(xpath('e f'),
                 "e//f")
    expect_equal(xpath('e > f'),
                 "e/f")
    expect_equal(xpath('e + f'),
                 "e/following-sibling::*[1][self::f]")
    expect_equal(xpath('e ~ f'),
                 "e/following-sibling::f")
    expect_equal(xpath('div#container p'),
                 "div[(@id = 'container')]//p")
})

test_that("translation of unsafe XPath names works", {
    charsets <- localeToCharset()
    if (!anyNA(charsets) && charsets[1] == "UTF-8") {
        expect_equal(xpath('di\ua0v'),
                     "*[(name() = 'di\ua0v')]")
        expect_equal(xpath('[h\ua0ref]'),
                     "*[(attribute::*[name() = 'h\ua0ref'])]")
    }
    expect_equal(xpath('di\\[v'),
                 "*[(name() = 'di[v')]")
    expect_equal(xpath('[h\\]ref]'),
                 "*[(attribute::*[name() = 'h]ref'])]")
    # Unicode escapes are decoded to the characters they represent,
    # in idents, hashes, and strings alike
    expect_equal(xpath("#\\31 23"), "*[(@id = '123')]")
    expect_equal(xpath("\\31 23"), "*[(name() = '123')]")
    expect_equal(xpath("[\\31 23]"),
                 "*[(attribute::*[name() = '123'])]")
    expect_equal(xpath("e[foo='\\31 23']"), "e[(@foo = '123')]")
    expect_equal(xpath("e[foo='x\\79 z']"), "e[(@foo = 'xyz')]")
})

test_that("unsupported constructs error informatively", {
    # selectr translates [a!=b] (non-standard); Servo's attribute parser has
    # no hook for it. Decided (2026-06-04): permanently ignored.
    expect_error(xpath('e[foo!="bar"]'), "parse")
    # Malformed case-sensitivity flags error in both implementations.
    expect_error(xpath('[rel i]'))
    expect_error(xpath('[rel=stylesheet k]'))
    expect_error(xpath('[rel=stylesheet i i]'))
    # Parse failures name the selector.
    expect_error(xpath('e:'), "e:")
})

test_that("css_to_xpath vectorises arguments", {
    # Ported from selectr's test-main.R (css_to_xpath portion); the
    # html/xhtml translator case moves here in Phase 2 with :checked.
    expect_equal(css_to_xpath("a b"), "descendant-or-self::a//b")
    expect_equal(css_to_xpath("a b", prefix = ""), "a//b")
    expect_equal(css_to_xpath("a b", prefix = c("descendant-or-self::", "")),
                 c("descendant-or-self::a//b", "a//b"))
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

    # should strip the NA values out
    expect_warning(res <- css_to_xpath(c("a", NA)), "NA values")
    expect_length(res, 1)
    expect_warning(res <- css_to_xpath("a", prefix = c("", NA)), "NA values")
    expect_length(res, 1)
    expect_warning(res <- css_to_xpath("a", translator = c("generic", NA)), "NA values")
    expect_length(res, 1)

    # expect NAs to be stripped out resulting in zero length args (unusable)
    expect_error(suppressWarnings(css_to_xpath(NA_character_)), "Zero length character vector.*")
    expect_error(suppressWarnings(css_to_xpath("a", prefix = NA_character_)), "Zero length character vector.*")
    expect_error(suppressWarnings(css_to_xpath("a", translator = NA_character_)), "Zero length character vector.*")

    # performs partial matching
    expect_equal(css_to_xpath("a", translator = "g"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = "gEnErIC"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = "h"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = "x"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = c("g", "h", "x")),
                 rep("descendant-or-self::a", 3))

    # errors anything not matching generic, html, xhtml
    expect_error(css_to_xpath("a", translator = ""), "'arg' should be one of.*")
    expect_error(css_to_xpath("a", translator = "a"), "'arg' should be one of.*")
    expect_error(css_to_xpath("a", translator = c("generic", "a")), "'arg' should be one of.*")
})
