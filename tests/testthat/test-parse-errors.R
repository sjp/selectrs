# Invalid selectors are asserted as "errors, with a message naming the
# selector"; selectrs' exact wording is pinned by the snapshot test at the
# bottom of this file.
#
# Constructs left unclosed at end of input ("[rel=stylesheet",
# "[rel=stylesheet i", ":lang(fr") are not errors: css-syntax-3 auto-closes
# open blocks/functions/strings at EOF (flagging a parse error but
# returning the construct), which is also what browsers' querySelector
# does. These parse and translate exactly as their closed forms (asserted
# below).

test_that("invalid selectors error, naming the selector", {
    err <- function(css) {
        expect_error(css_to_xpath(css),
                     paste0('CSS selector "', css, '"'), fixed = TRUE)
    }

    err("attributes(href)/html/body/a")
    err("attributes(href)")
    err("html/body/a")
    err(" ")
    err("div, ")
    err(" , div")
    err("p, , div")
    err("div > ")
    err("  > div")
    err("foo|#bar")
    err("#.foo")
    err(".#foo")
    err(":#foo")
    err("[*]")
    err("[foo|]")
    err("[#]")
    err("[foo=#]")
    err(":nth-child()")
    err("[href]a")
    expect_no_error(css_to_xpath("[rel=stylesheet]"))
    err("[rel:stylesheet]")
    err("[rel=stylesheet k]")
    err("[rel=stylesheet i i]")
    # A case-sensitivity flag requires an operator and value
    err("[rel i]")
    expect_no_error(css_to_xpath(":lang(fr)"))
    # :contains() is auto-closed at EOF (see header) but remains an
    # unsupported pseudo-class, so these still error. (Asserted by pattern:
    # the message escapes the embedded quote when echoing the selector, so
    # the verbatim form used by err() would not match.)
    expect_error(css_to_xpath(':contains("foo'), "contains")
    expect_error(css_to_xpath(':contains("foo\\"'), "contains")
    err("foo!")
    # The non-standard != attribute operator is not supported
    err("a[rel!=nofollow]")
    err("a:not(b;)")

    # Mis-placed pseudo-elements (selectrs rejects pseudo-elements outright,
    # so these error wherever they appear)
    err("a:before:empty")
    err("li:before a")
    err(":not(:before)")
    err(":not(a,)")
    err(":is(:before)")
    err(":matches(:before)")
})

test_that("constructs unclosed at EOF translate as their closed forms", {
    # css-syntax-3 conformance (see header).
    eof <- function(unclosed, closed) {
        for (translator in c("generic", "html", "xhtml")) {
            expect_equal(css_to_xpath(unclosed, translator = translator),
                         css_to_xpath(closed, translator = translator))
        }
    }
    eof("[rel=stylesheet",   "[rel=stylesheet]")    # unclosed block
    eof("[rel=stylesheet i", "[rel=stylesheet i]")  # unclosed block + flag
    eof(":lang(fr",          ":lang(fr)")           # unclosed function
    eof('[foo="bar',         '[foo="bar"]')         # unclosed string
})

test_that("selectrs' parse-error wording is stable", {
    # One representative per error family; the exact text is pinned here
    # so it only changes deliberately.
    expect_snapshot(error = TRUE, css_to_xpath(" "))                  # empty selector
    expect_snapshot(error = TRUE, css_to_xpath("div > "))             # dangling combinator
    expect_snapshot(error = TRUE, css_to_xpath("foo!"))               # unexpected token
    expect_snapshot(error = TRUE, css_to_xpath("foo|#bar"))           # bad namespace position
    expect_snapshot(error = TRUE, css_to_xpath("[rel i]"))            # flag without operator
    expect_snapshot(error = TRUE, css_to_xpath("a[rel!=nofollow]"))   # non-standard operator
    expect_snapshot(error = TRUE, css_to_xpath('e:contains("foo")'))  # unknown pseudo-class
    expect_snapshot(error = TRUE, css_to_xpath("e::before"))          # pseudo-element
    expect_snapshot(error = TRUE, css_to_xpath("e:lang(-)"))          # bad :lang() argument
    expect_snapshot(error = TRUE, css_to_xpath("col || td"))          # column combinator
    expect_snapshot(error = TRUE, css_to_xpath("e:is(> a)"))          # leading combinator outside :has()
    expect_snapshot(error = TRUE, css_to_xpath("e:has(a:has(b))"))    # nested :has()
    expect_snapshot(error = TRUE, css_to_xpath("*:first-of-type"))    # of-type on '*'
    expect_snapshot(error = TRUE, css_to_xpath("e:nth-child(3 7)"))   # fused An+B
    expect_snapshot(error = TRUE, css_to_xpath("e:nth-child(2.5)"))   # non-integer An+B
})
