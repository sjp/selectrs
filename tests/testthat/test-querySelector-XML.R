# What the XML package does that xml2 does not: it registers no namespace
# for a query unless one is passed, so an unprefixed selector against a
# document with a default namespace matches nothing and libxml2 says so.
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

test_that("a zero-length namespace leaves XML to resolve prefixes itself", {
    skip_if_not_installed("XML")
    # getNodeSet() called without a namespaces argument defaults to the
    # declarations the document itself carries, so a prefixed selector
    # still resolves — a zero-length `ns` only skips selectrs' own map.
    doc <- XML::xmlParse('<r xmlns:s="urn:s"><s:b id="1"/></r>', asText = TRUE)
    found <- querySelectorAll(doc, "s|b", ns = character(0))
    expect_equal(XML::xmlGetAttr(found[[1]], "id"), "1")
})
