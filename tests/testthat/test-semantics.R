# The translation itself belongs to the css-to-xpath crate, whose own
# tests compare XPath strings. What only this package can pin is what
# those strings then *match*, so each test here evaluates a translated
# selector against a real document. They exist so that a crate upgrade
# cannot quietly move a matching behaviour selectrs depends on.

xhtmlDoc <- function(backend)
    backend$parse(paste0(
        '<html xmlns="http://www.w3.org/1999/xhtml"><body>',
        '<p id="one">1</p><p id="two">2</p></body></html>'))

xhtmlNs <- c(h = "http://www.w3.org/1999/xhtml")

forEachBackend("a name in a functional pseudo-class is in no namespace", function(backend) {
    doc <- xhtmlDoc(backend)
    found <- function(selector, ns = xhtmlNs)
        backend$ids(querySelectorAll(doc, selector, ns))

    # An unprefixed name means the null namespace wherever it appears, so
    # the arguments of these agree with a bare name rather than reaching
    # into the document's default namespace.
    expect_equal(length(found("p")), 0L)
    expect_equal(length(found(":is(p)")), 0L)
    expect_equal(length(found("p + p")), 0L)
    expect_equal(length(found(":is(p + p)")), 0L)
    expect_equal(length(found("body :has(p)")), 0L)
    expect_equal(length(found(":nth-child(1 of p)")), 0L)

    # prefixed, all of them match
    expect_equal(found("h|p"), c("one", "two"))
    expect_equal(found(":is(h|p)"), c("one", "two"))
    expect_equal(found("h|p + h|p"), "two")
    matched <- backend$nodes(querySelectorAll(doc, "h|body:has(h|p)", xhtmlNs))
    expect_equal(vapply(matched, backend$elementName, character(1)), "body")
})

forEachBackend("generic :lang(*) needs a non-empty inherited language", function(backend) {
    doc <- backend$parse('<r><a/><b xml:lang="en"/><c xml:lang=""/></r>')
    matched <- vapply(backend$nodes(querySelectorAll(doc, ":lang(*)")),
                      backend$elementName, character(1))
    expect_equal(matched, "b")
})

forEachBackend("an option in a disabled optgroup is :disabled", function(backend) {
    doc <- backend$parseHtml(paste0(
        '<select><optgroup disabled><option id="in">a</option></optgroup>',
        '<option id="out">b</option></select>'))
    expect_equal(backend$ids(querySelectorAll(doc, "option:disabled",
                                              translator = "html")), "in")
    expect_equal(backend$ids(querySelectorAll(doc, "option:enabled",
                                              translator = "html")), "out")
})

forEachBackend("the xhtml translator reads xml:lang", function(backend) {
    doc <- backend$parse('<r xmlns="http://x"><p id="p" xml:lang="en">hi</p></r>')
    expect_equal(backend$ids(querySelectorAll(doc, "*|p:lang(en)",
                                              translator = "xhtml")), "p")
    # the html translator reads `lang`, which an XML document does not set
    expect_equal(length(querySelectorAll(doc, "*|p:lang(en)",
                                         translator = "html")), 0L)
})

forEachBackend("html :enabled is confined to the elements HTML defines it over", function(backend) {
    doc <- backend$parseHtml(paste0(
        '<body><a href="#" id="a">x</a><button id="b">y</button>',
        '<input id="i"></body>'))
    expect_equal(backend$ids(querySelectorAll(doc, ":enabled",
                                              translator = "html")),
                 c("b", "i"))
})

forEachBackend("an empty :is() or :where() matches nothing", function(backend) {
    doc <- backend$parse('<r><a/><b/></r>')
    expect_equal(length(querySelectorAll(doc, ":is()")), 0L)
    expect_equal(length(querySelectorAll(doc, ":where()")), 0L)
    expect_equal(length(querySelectorAll(doc, "a:is()")), 0L)
})

test_that("an of-type pseudo-class needs a type, prefixed wildcard included", {
    # a prefixed wildcard names a namespace, not a type, so counting its
    # siblings would answer a different question than the selector asks
    expect_error(css_to_xpath("svg|*:first-of-type"),
                 "an of-type pseudo-class on the universal selector",
                 fixed = TRUE)
    expect_error(css_to_xpath("*:first-of-type"),
                 "an of-type pseudo-class on the universal selector",
                 fixed = TRUE)
    # an any-namespace type still has one, and counts by local name
    expect_equal(css_to_xpath("*|p:first-of-type", prefix = ""),
                 paste0("*[local-name() = 'p' and ",
                        "count(preceding-sibling::*[local-name() = 'p']) = 0]"))
})

test_that(":lang() takes a comma-separated list of language ranges", {
    expect_equal(css_to_xpath(":lang(en, fr)", prefix = ""),
                 "*[lang('en') or lang('fr')]")
    # space-separated, and a range that is not one, are rejected rather
    # than silently read as something else
    expect_error(css_to_xpath(":lang(en fr)"))
    expect_error(css_to_xpath(":lang(en *)"))
    expect_error(css_to_xpath(":lang(en*)"))
    expect_error(css_to_xpath(':lang("")'))
})

test_that("a namespace prefix survives a local name that needs quoting", {
    # the local name folds into local-name(), but the prefix stays in the
    # node test, so the document's own binding for it still applies
    xpath <- css_to_xpath("svg|di\\[v", prefix = "")
    expect_equal(xpath, "svg:*[local-name() = 'di[v']")
    expect_false(grepl("name() = 'svg:", xpath, fixed = TRUE))
})

test_that("html :checked is confined to HTML's element set", {
    # `command` was dropped from HTML long ago, and a name outside the
    # set collapses rather than being left for the XPath engine
    expect_equal(css_to_xpath("a:checked", prefix = "", translator = "html"),
                 "a[0]")
    expect_equal(css_to_xpath("option:checked", prefix = "", translator = "html"),
                 "option[@selected]")
    expect_false(grepl("command",
                       css_to_xpath(":checked", prefix = "", translator = "html"),
                       fixed = TRUE))
})

test_that("a parse failure is described in prose, not a dependency's Debug output", {
    detail <- function(selector) {
        e <- tryCatch(css_to_xpath(selector), error = identity)
        sub("^[^:]*: ", "", strsplit(conditionMessage(e), "\n", fixed = TRUE)[[1]][[1]])
    }
    expect_equal(detail("div >"), "a combinator with nothing after it")
    expect_equal(detail("a["), "the selector ends unexpectedly")
    expect_match(detail(":nth-child(zzz)"), "unexpected `zzz`", fixed = TRUE)
    expect_match(detail("::slotted(x)"),
                 "not a supported pseudo-class or pseudo-element", fixed = TRUE)
})
