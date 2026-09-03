# What xml2 does that the XML package does not: with no `ns` argument it
# collects the document's own namespace declarations with xml_ns(), so an
# unprefixed selector resolves against the default namespace without a
# warning; it has an xml_missing class for "no match"; and its nodes know
# the document they came from. The rest of the querySelector* contract is
# in test-querySelector.R.

svgDoc <- function() {
    xml2::read_xml(paste0(
        '<svg xmlns="http://www.w3.org/2000/svg">',
        '<circle cx="10" cy="10" r="10"/>',
        '<circle cx="20" cy="20" r="20"/>',
        '<circle cx="30" cy="30" r="30"/>',
        '</svg>'))
}

test_that("querySelector handles namespaces", {
    skip_if_not_installed("xml2")
    svg <- c(svg = "http://www.w3.org/2000/svg")
    doc <- svgDoc()
    p <- function(x) if (is.null(x)) x else as.character(x)
    circle <- function() {
        xml2::xml_find_all(doc, "//svg:circle", ns = svg)[[1]]
    }

    expect_null(querySelector(doc, "circle"))
    expect_null(querySelector(doc, "circle", ns = svg))
    expect_equal(p(querySelector(doc, "svg|circle", ns = svg)), p(circle()))

    # now with querySelectorNS
    expect_null(querySelectorNS(doc, "circle", svg))
    expect_equal(p(querySelectorNS(doc, "svg|circle", svg)), p(circle()))
})

test_that("querySelectorAll handles namespaces", {
    skip_if_not_installed("xml2")
    svg <- c(svg = "http://www.w3.org/2000/svg")
    doc <- svgDoc()
    p <- function(x) lapply(x, as.character)

    expect_equal(p(querySelectorAll(doc, "circle")),
                 p(xml2::xml_find_all(doc, "//circle")))
    expect_equal(p(querySelectorAll(doc, "circle", ns = svg)),
                 p(xml2::xml_find_all(doc, "//circle", ns = svg)))
    expect_equal(p(querySelectorAll(doc, "svg|circle", ns = svg)),
                 p(xml2::xml_find_all(doc, "//svg:circle", ns = svg)))

    # now with querySelectorAllNS
    expect_equal(p(querySelectorAllNS(doc, "circle", svg)),
                 p(xml2::xml_find_all(doc, "//circle", ns = svg)))
    expect_equal(p(querySelectorAllNS(doc, "svg|circle", svg)),
                 p(xml2::xml_find_all(doc, "//svg:circle", ns = svg)))
})

test_that("an xml_ns() namespace map can be handed straight to the queries", {
    skip_if_not_installed("xml2")
    # xml_ns() returns an xml_namespace-classed character vector, and the
    # prefixes it invents for a default namespace (d1, d2, ...) are the ones
    # a selector then has to use.
    doc <- xml2::read_xml(paste0(
        '<r xmlns="urn:default" xmlns:s="urn:s">',
        '<a id="1"/><s:a id="2"/>',
        '</r>'))
    ns <- xml2::xml_ns(doc)
    expect_s3_class(ns, "xml_namespace")
    expect_equal(sort(names(ns)), c("d1", "s"))

    expect_equal(xml2::xml_attr(querySelectorAll(doc, "d1|a", ns = ns), "id"), "1")
    expect_equal(xml2::xml_attr(querySelectorAllNS(doc, "d1|a", ns), "id"), "1")
    expect_equal(xml2::xml_attr(querySelectorNS(doc, "s|a", ns), "id"), "2")
    # the *NS filter keeps only the namespaces it was given, so asking for
    # both prefixes returns both elements
    expect_equal(xml2::xml_attr(querySelectorAllNS(doc, "*|a", ns), "id"),
                 c("1", "2"))
})

test_that("a zero-length namespace leaves xml2 with no prefix to resolve", {
    skip_if_not_installed("xml2")
    # xml_find_all() registers only the map it is handed, so with none a
    # prefixed selector is left to libxml2 to complain about.
    doc <- xml2::read_xml('<r xmlns:s="urn:s"><s:b id="1"/></r>')
    expect_warning(querySelectorAll(doc, "s|b", ns = character(0)),
                   "Undefined namespace prefix")
    expect_equal(length(suppressWarnings(querySelectorAll(doc, "s|b",
                                                          ns = character(0)))), 0L)
})

test_that("querying an xml_missing gives an empty result", {
    skip_if_not_installed("xml2")
    doc <- xml2::read_xml("<a><b/></a>")
    missing <- xml2::xml_find_first(doc, "//nosuchelement")
    expect_true(inherits(missing, "xml_missing"))

    res <- querySelectorAll(missing, "b")
    expect_true(inherits(res, "xml_nodeset"))
    expect_equal(length(res), 0)
    expect_null(querySelector(missing, "b"))

    # The namespaced variants are equally quiet
    svg <- c(svg = "http://www.w3.org/2000/svg")
    expect_equal(length(querySelectorAllNS(missing, "svg|circle", svg)), 0)
    expect_null(querySelectorNS(missing, "svg|circle", svg))
})

test_that("the xml_missing methods validate their arguments", {
    skip_if_not_installed("xml2")
    doc <- xml2::read_xml("<a><b/></a>")
    missing <- xml2::xml_find_first(doc, "//nosuchelement")

    expect_error(querySelectorAll(missing, c("b", "c")),
                 "A valid selector .*must be provided")
    expect_error(querySelectorAllNS(missing, "b"),
                 "A namespace must be provided.")
    expect_error(querySelectorNS(missing, "b"), "A namespace must be provided.")
})

test_that("nodes and node sets of an HTML document are detected", {
    skip_if_not_installed("xml2")
    # Unlike an XML node, an xml_node keeps a reference to its document, so
    # a query starting from one still uses the html translator.
    doc <- xml2::read_html(translatorHtml())
    node <- querySelector(doc, "div")
    nodeset <- querySelectorAll(doc, "div")

    expect_equal(length(querySelectorAll(node, "input:checked")), 1)
    expect_false(is.null(querySelector(node, "input:checked")))
    expect_equal(length(querySelectorAll(nodeset, "input:checked")), 1)
    expect_false(is.null(querySelector(nodeset, "input:checked")))

    # A missing node has no document to inspect, and must not error
    xdoc <- xml2::read_xml('<a><B/></a>')
    expect_equal(length(querySelectorAll(xml2::xml_find_first(xdoc, "//zz"),
                                         "B")), 0)
})
