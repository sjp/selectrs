# What the XML package does that xml2 does not: it registers no namespace
# for a query unless one is passed, so an unprefixed selector against a
# document with a default namespace matches nothing and libxml2 says so;
# and it can build a node that belongs to no document at all.
# The rest of the querySelector* contract is in test-querySelector.R.

svgDoc <- function() {
    XML::xmlParse(paste0(
        '<svg xmlns="http://www.w3.org/2000/svg">',
        '<circle cx="10" cy="10" r="10"/>',
        '<circle cx="20" cy="20" r="20"/>',
        '<circle cx="30" cy="30" r="30"/>',
        '</svg>'), asText = TRUE)
}

test_that("querySelector handles namespaces", {
    skip_if_not_installed("XML")
    svg <- c(svg = "http://www.w3.org/2000/svg")
    doc <- svgDoc()
    p <- function(x) if (is.null(x)) x else XML::saveXML(x, file = NULL)
    circle <- function() {
        XML::getNodeSet(doc, "//svg:circle", namespaces = svg)[[1]]
    }

    # (suppressWarnings: libxml2 warns that the query has no namespace while
    # the document has a default one — the NULL result is exactly the point)
    expect_null(suppressWarnings(querySelector(doc, "circle")))
    expect_null(querySelector(doc, "circle", ns = svg))
    expect_equal(p(querySelector(doc, "svg|circle", ns = svg)), p(circle()))

    # now with querySelectorNS
    expect_null(suppressWarnings(querySelectorNS(doc, "circle", svg)))
    expect_equal(p(querySelectorNS(doc, "svg|circle", svg)), p(circle()))
})

test_that("querySelectorAll handles namespaces", {
    skip_if_not_installed("XML")
    svg <- c(svg = "http://www.w3.org/2000/svg")
    doc <- svgDoc()
    p <- function(x) lapply(x, XML::saveXML, file = NULL)

    # (suppressWarnings: see the namespace note above)
    expect_equal(suppressWarnings(p(querySelectorAll(doc, "circle"))),
                 suppressWarnings(p(XML::getNodeSet(doc, "//circle"))))
    expect_equal(suppressWarnings(p(querySelectorAll(doc, "circle", ns = svg))),
                 suppressWarnings(p(XML::getNodeSet(doc, "//circle", namespaces = svg))))
    expect_equal(p(querySelectorAll(doc, "svg|circle", ns = svg)),
                 p(XML::getNodeSet(doc, "//svg:circle", namespaces = svg)))

    # now with querySelectorAllNS
    expect_equal(suppressWarnings(p(querySelectorAllNS(doc, "circle", svg))),
                 suppressWarnings(p(XML::getNodeSet(doc, "//circle", namespaces = svg))))
    expect_equal(p(querySelectorAllNS(doc, "svg|circle", svg)),
                 p(XML::getNodeSet(doc, "//svg:circle", namespaces = svg)))
})

test_that("a zero-length namespace leaves XML with no prefix to resolve", {
    skip_if_not_installed("XML")
    # getNodeSet() is handed the empty map, so libxml2 cannot compile an
    # expression naming a prefix and says so as an error of its own rather
    # than a classed selectrs condition.
    doc <- XML::xmlParse('<r xmlns:s="urn:s"><c><s:b id="1"/></c></r>',
                         asText = TRUE)
    expect_error(querySelectorAll(doc, "s|b", ns = character(0)),
                 "error evaluating xpath expression")

    # the NULL default is getNodeSet()'s own, the declarations on the
    # element the query starts from, so a prefix declared higher up is out
    # of reach when the query starts below it
    node <- XML::getNodeSet(XML::xmlRoot(doc), "//c")[[1]]
    expect_error(querySelectorAll(node, "s|b"),
                 "error evaluating xpath expression")
    expect_equal(XML::xmlGetAttr(querySelectorAll(node, "s|b",
                                                  ns = c(s = "urn:s"))[[1]],
                                 "id"), "1")
})

test_that("a node belonging to no document is queried as XML", {
    skip_if_not_installed("XML")
    # newXMLNode() builds a node outside any document, so the "/" step has
    # nothing to reach and must not error.
    orphan <- XML::newXMLNode("DIV", XML::newXMLNode("B"))
    expect_equal(selectrs:::xmlTranslator(NULL, orphan), "generic")

    # libxml2 evaluates a relative axis from such a node against nothing,
    # so the query has to be anchored to reach the subtree at all.
    expect_equal(length(querySelectorAll(orphan, "B", prefix = "//")), 1)
})
