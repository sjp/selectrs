# Which translator a query picks when none is named: "html" for a document
# the backend parsed as HTML, "generic" otherwise. How each package lets a
# node or node set be traced back to its document differs, so those tests
# are in test-querySelector-XML.R and -xml2.R.

forEachBackend("HTML documents use the html translator by default",
               function(backend) {
    doc <- backend$parseHtml(translatorHtml())

    # Pseudo-classes that only the html translator implements
    expect_equal(length(querySelectorAll(doc, "input:checked")), 1)
    expect_equal(length(querySelectorAll(doc, ":disabled")), 1)
    expect_equal(length(querySelectorAll(doc, ":link")), 1)
    expect_equal(length(querySelectorAll(doc, ":lang(en)")), 4)

    # Element and attribute names are matched case-insensitively
    expect_equal(length(querySelectorAll(doc, "DIV")), 1)
    expect_equal(length(querySelectorAll(doc, "[HREF]")), 1)

    expect_false(is.null(querySelector(doc, "input:checked")))
})

forEachBackend("an explicit translator overrides the html default",
               function(backend) {
    doc <- backend$parseHtml(translatorHtml())

    expect_equal(length(querySelectorAll(doc, "input:checked",
                                         translator = "generic")), 0)
    expect_null(querySelector(doc, "input:checked", translator = "generic"))
    # css_to_xpath()'s arguments are matched partially, so an abbreviated
    # argument counts as explicit too
    expect_equal(length(querySelectorAll(doc, "input:checked",
                                         trans = "generic")), 0)
})

forEachBackend("XML documents keep the generic translator", function(backend) {
    doc <- backend$parse('<a><B/><input type="checkbox" checked="checked"/></a>')
    expect_equal(length(querySelectorAll(doc, "B")), 1)
    expect_equal(length(querySelectorAll(doc, "b")), 0)
    expect_equal(length(querySelectorAll(doc, "input:checked")), 0)

    node <- querySelector(doc, "a")
    expect_equal(length(querySelectorAll(node, "B")), 1)

    # An empty node set has no document to inspect, and must not error
    expect_equal(length(querySelectorAll(querySelectorAll(doc, "zz"), "B")), 0)
})

forEachBackend("namespaced queries on an HTML document use the html translator",
               function(backend) {
    doc <- backend$parseHtml(translatorHtml())
    ns <- c(x = "http://www.w3.org/1999/xhtml")
    # Neither package puts an HTML document in a namespace, so these match
    # nothing; the point is that the translator still applies
    expect_equal(length(querySelectorAllNS(doc, "x|input:checked", ns)), 0)
    expect_null(querySelectorNS(doc, "x|input:checked", ns))
})

test_that("css_to_xpath() still defaults to the generic translator", {
    expect_equal(css_to_xpath("input:checked"),
                 css_to_xpath("input:checked", translator = "generic"))
})
