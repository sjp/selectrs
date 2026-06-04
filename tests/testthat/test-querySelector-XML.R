test_that("querySelector returns a single node or NULL", {
    skip_if_not_installed("XML")
    library(XML)
    doc <- xmlRoot(xmlParse('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>'))
    p <- function(x) {
        if (is.null(x))
            return(x)
        saveXML(x, file = NULL)
    }
    expect_equal(p(querySelector(doc, "a")), p(getNodeSet(doc, "//a")[[1]]))
    expect_equal(p(querySelector(doc, "*", prefix = "")), p(getNodeSet(doc, "*")[[1]]))
    expect_equal(p(querySelector(doc, "d")), NULL)
    expect_equal(p(querySelector(doc, "c")), p(getNodeSet(doc, "//c")[[1]]))

    # do the same again but on the xml doc itself
    doc <- xmlParse('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>')
    expect_equal(p(querySelector(doc, "a")), p(getNodeSet(xmlRoot(doc), "//a")[[1]]))
    expect_equal(p(querySelector(doc, "*", prefix = "")), p(getNodeSet(xmlRoot(doc), "*")[[1]]))
    expect_equal(p(querySelector(doc, "d")), NULL)
    expect_equal(p(querySelector(doc, "c")), p(getNodeSet(xmlRoot(doc), "//c")[[1]]))
})

test_that("querySelectorAll returns expected nodes", {
    skip_if_not_installed("XML")
    library(XML)
    doc <- xmlRoot(xmlParse('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>'))
    p <- function(x) {
        lapply(x, function(node) saveXML(node, file = NULL))
    }
    expect_equal(p(querySelectorAll(doc, "a")), p(getNodeSet(doc, "//a")))
    expect_equal(p(querySelectorAll(doc, "*", prefix = "")), p(getNodeSet(doc, "*")))
    expect_equal(p(querySelectorAll(doc, "c")), p(getNodeSet(doc, "//c")))

    # do the same again but on the xml doc itself
    doc <- xmlParse('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>')
    expect_equal(p(querySelectorAll(doc, "a")), p(getNodeSet(xmlRoot(doc), "//a")))
    expect_equal(p(querySelectorAll(doc, "*", prefix = "")), p(getNodeSet(xmlRoot(doc), "*")))
    expect_equal(p(querySelectorAll(doc, "c")), p(getNodeSet(xmlRoot(doc), "//c")))
})

test_that("querySelectorAll returns empty list for no match", {
    skip_if_not_installed("XML")
    library(XML)
    doc <- xmlRoot(xmlParse('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>'))
    p <- function(x) {
        lapply(x, function(node) saveXML(node, file = NULL))
    }
    expect_equal(p(querySelectorAll(doc, "d")), p(getNodeSet(doc, "//d")))
})

test_that("querySelector handles namespaces", {
    skip_if_not_installed("XML")
    library(XML)
    doc <- xmlRoot(xmlParse('<svg xmlns="http://www.w3.org/2000/svg"><circle cx="10" cy="10" r="10"/><circle cx="20" cy="20" r="20"/><circle cx="30" cy="30" r="30"/></svg>'))
    p <- function(x) {
        if (is.null(x)) x else saveXML(x, file = NULL)
    }

    # (suppressWarnings: libxml2 warns that the query has no namespace while
    # the document has a default one — the NULL result is exactly the point)
    expect_equal(suppressWarnings(querySelector(doc, "circle")), NULL)
    expect_equal(querySelector(doc, "circle", ns = c(svg = "http://www.w3.org/2000/svg")), NULL)
    expect_equal(p(querySelector(doc, "svg|circle", ns = c(svg = "http://www.w3.org/2000/svg"))), p(getNodeSet(doc, "//svg:circle", namespaces = c(svg = "http://www.w3.org/2000/svg"))[[1]]))

    # now with querySelectorNS
    expect_equal(suppressWarnings(querySelectorNS(doc, "circle", c(svg = "http://www.w3.org/2000/svg"))), NULL)
    expect_equal(p(querySelectorNS(doc, "svg|circle", c(svg = "http://www.w3.org/2000/svg"))), p(getNodeSet(doc, "//svg:circle", namespaces = c(svg = "http://www.w3.org/2000/svg"))[[1]]))
})

test_that("querySelectorAll handles namespaces", {
    skip_if_not_installed("XML")
    library(XML)
    doc <- xmlRoot(xmlParse('<svg xmlns="http://www.w3.org/2000/svg"><circle cx="10" cy="10" r="10"/><circle cx="20" cy="20" r="20"/><circle cx="30" cy="30" r="30"/></svg>'))
    p <- function(x) {
        lapply(x, function(node) saveXML(node, file = NULL))
    }

    # (suppressWarnings: see the namespace note above)
    expect_equal(suppressWarnings(p(querySelectorAll(doc, "circle"))), suppressWarnings(p(getNodeSet(doc, "//circle"))))
    expect_equal(suppressWarnings(p(querySelectorAll(doc, "circle", ns = c(svg = "http://www.w3.org/2000/svg")))), suppressWarnings(p(getNodeSet(doc, "//circle", namespaces = c(svg = "http://www.w3.org/2000/svg")))))
    expect_equal(p(querySelectorAll(doc, "svg|circle", ns = c(svg = "http://www.w3.org/2000/svg"))), p(getNodeSet(doc, "//svg:circle", namespaces = c(svg = "http://www.w3.org/2000/svg"))))

    # now with querySelectorAllNS
    expect_equal(suppressWarnings(p(querySelectorAllNS(doc, "circle", c(svg = "http://www.w3.org/2000/svg")))), suppressWarnings(p(getNodeSet(doc, "//circle", namespaces = c(svg = "http://www.w3.org/2000/svg")))))
    expect_equal(p(querySelectorAllNS(doc, "svg|circle", c(svg = "http://www.w3.org/2000/svg"))), p(getNodeSet(doc, "//svg:circle", namespaces = c(svg = "http://www.w3.org/2000/svg"))))
})

test_that("querySelector methods handle invalid arguments", {
    skip_if_not_installed("XML")
    library(XML)
    doc <- xmlParse('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>')

    selector_error <- "A valid selector (single character string) must be provided."
    expect_error(querySelector(doc), selector_error, fixed = TRUE)
    expect_error(querySelectorAll(doc), selector_error, fixed = TRUE)
    expect_error(querySelectorNS(doc), selector_error, fixed = TRUE)
    expect_error(querySelectorAllNS(doc), selector_error, fixed = TRUE)

    # selectors must be a single string, not a vector
    expect_error(querySelector(doc, c("b", "c")), selector_error, fixed = TRUE)
    expect_error(querySelectorAll(doc, c("b", "c")), selector_error, fixed = TRUE)
    expect_error(querySelectorNS(doc, c("b", "c"), c(svg = "http://www.w3.org/2000/svg")), selector_error, fixed = TRUE)
    expect_error(querySelectorAllNS(doc, c("b", "c"), c(svg = "http://www.w3.org/2000/svg")), selector_error, fixed = TRUE)
    expect_error(querySelectorAll(doc, character(0)), selector_error, fixed = TRUE)
    expect_error(querySelectorAll(doc, 1), selector_error, fixed = TRUE)
    expect_error(querySelectorAll(doc, NULL), selector_error, fixed = TRUE)

    expect_error(querySelectorNS(doc, "a"), "A namespace must be provided.", fixed = TRUE)
    expect_error(querySelectorNS(doc, "a", NULL), "A namespace must be provided.", fixed = TRUE)
    expect_error(querySelectorNS(doc, "a", character(0)), "A namespace must be provided.", fixed = TRUE)
    expect_error(querySelectorAllNS(doc, "a"), "A namespace must be provided.", fixed = TRUE)
    expect_error(querySelectorAllNS(doc, "a", NULL), "A namespace must be provided.", fixed = TRUE)
    expect_error(querySelectorAllNS(doc, "a", character(0)), "A namespace must be provided.", fixed = TRUE)
})
