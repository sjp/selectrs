test_that("querySelector returns a single node or NULL", {
    skip_if_not_installed("xml2")
    library(xml2)
    doc <- read_xml('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>')
    p <- function(x) {
        if (is.null(x)) x else as.character(x)
    }
    expect_equal(p(querySelector(doc, "a")), p(xml_find_first(doc, "//a")))
    expect_equal(p(querySelector(doc, "*", prefix = "")), p(xml_find_first(doc, "*")))
    expect_equal(p(querySelector(doc, "d")), NULL)
    expect_equal(p(querySelector(doc, "c")), p(xml_find_first(doc, "//c")))
})

test_that("querySelectorAll returns expected nodes", {
    skip_if_not_installed("xml2")
    library(xml2)
    doc <- read_xml('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>')
    p <- function(x) {
        lapply(x, function(node) as.character(node))
    }
    expect_equal(p(querySelectorAll(doc, "a")), p(xml_find_all(doc, "//a")))
    expect_equal(p(querySelectorAll(doc, "*", prefix = "")), p(xml_find_all(doc, "*")))
    expect_equal(p(querySelectorAll(doc, "c")), p(xml_find_all(doc, "//c")))
})

test_that("querySelectorAll returns empty list for no match", {
    skip_if_not_installed("xml2")
    library(xml2)
    doc <- read_xml('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>')
    p <- function(x) {
        lapply(x, function(node) as.character(node))
    }
    expect_equal(p(querySelectorAll(doc, "d")), p(xml_find_all(doc, "//d")))
})

test_that("querySelector handles namespaces", {
    skip_if_not_installed("xml2")
    library(xml2)
    doc <- read_xml('<svg xmlns="http://www.w3.org/2000/svg"><circle cx="10" cy="10" r="10"/><circle cx="20" cy="20" r="20"/><circle cx="30" cy="30" r="30"/></svg>')
    p <- function(x) {
        if (is.null(x)) x else as.character(x)
    }

    expect_equal(querySelector(doc, "circle"), NULL)
    expect_equal(querySelector(doc, "circle", ns = c(svg = "http://www.w3.org/2000/svg")), NULL)
    expect_equal(p(querySelector(doc, "svg|circle", ns = c(svg = "http://www.w3.org/2000/svg"))), p(xml_find_all(doc, "//svg:circle", ns = c(svg = "http://www.w3.org/2000/svg"))[[1]]))

    # now with querySelectorNS
    expect_equal(querySelectorNS(doc, "circle", c(svg = "http://www.w3.org/2000/svg")), NULL)
    expect_equal(p(querySelectorNS(doc, "svg|circle", c(svg = "http://www.w3.org/2000/svg"))), p(xml_find_all(doc, "//svg:circle", ns = c(svg = "http://www.w3.org/2000/svg"))[[1]]))
})

test_that("querySelectorAll handles namespaces", {
    skip_if_not_installed("xml2")
    library(xml2)
    doc <- read_xml('<svg xmlns="http://www.w3.org/2000/svg"><circle cx="10" cy="10" r="10"/><circle cx="20" cy="20" r="20"/><circle cx="30" cy="30" r="30"/></svg>')
    p <- function(x) {
        lapply(x, function(node) as.character(node))
    }

    expect_equal(p(querySelectorAll(doc, "circle")), p(xml_find_all(doc, "//circle")))
    expect_equal(p(querySelectorAll(doc, "circle", ns = c(svg = "http://www.w3.org/2000/svg"))), p(xml_find_all(doc, "//circle", ns = c(svg = "http://www.w3.org/2000/svg"))))
    expect_equal(p(querySelectorAll(doc, "svg|circle", ns = c(svg = "http://www.w3.org/2000/svg"))), p(xml_find_all(doc, "//svg:circle", ns = c(svg = "http://www.w3.org/2000/svg"))))

    # now with querySelectorAllNS
    expect_equal(p(querySelectorAllNS(doc, "circle", c(svg = "http://www.w3.org/2000/svg"))), p(xml_find_all(doc, "//circle", ns = c(svg = "http://www.w3.org/2000/svg"))))
    expect_equal(p(querySelectorAllNS(doc, "svg|circle", c(svg = "http://www.w3.org/2000/svg"))), p(xml_find_all(doc, "//svg:circle", ns = c(svg = "http://www.w3.org/2000/svg"))))
})

test_that("a named list works the same as a named character vector for ns", {
    skip_if_not_installed("xml2")
    library(xml2)
    doc <- read_xml('<svg xmlns="http://www.w3.org/2000/svg"><circle cx="10" cy="10" r="10"/></svg>')
    ns_chr <- c(svg = "http://www.w3.org/2000/svg")
    ns_list <- list(svg = "http://www.w3.org/2000/svg")
    p <- function(x) {
        if (is.null(x)) x else as.character(x)
    }
    pAll <- function(x) {
        lapply(x, function(node) as.character(node))
    }

    expect_equal(p(querySelector(doc, "svg|circle", ns = ns_list)),
                 p(querySelector(doc, "svg|circle", ns = ns_chr)))
    expect_equal(pAll(querySelectorAll(doc, "svg|circle", ns = ns_list)),
                 pAll(querySelectorAll(doc, "svg|circle", ns = ns_chr)))
    expect_equal(p(querySelectorNS(doc, "svg|circle", ns_list)),
                 p(querySelectorNS(doc, "svg|circle", ns_chr)))
    expect_equal(pAll(querySelectorAllNS(doc, "svg|circle", ns_list)),
                 pAll(querySelectorAllNS(doc, "svg|circle", ns_chr)))

    # malformed namespace objects are still rejected
    expect_error(querySelectorAll(doc, "svg|circle", ns = list(svg = 1)),
                 "The values in the namespace object.*")
    expect_error(querySelectorAll(doc, "svg|circle", ns = c("http://www.w3.org/2000/svg")),
                 "The namespace object is missing some or all names.*")
    expect_error(querySelectorAll(doc, "svg|circle",
                                  ns = list(svg = c("http://www.w3.org/2000/svg", "extra"))),
                 "Each element in the namespace object must be a single character string.")
})

test_that("querySelectorAll honours attribute case-sensitivity flags", {
    skip_if_not_installed("xml2")
    library(xml2)
    doc <- read_xml('<r><a rel="NoFollow"/><a rel="nofollow"/><a rel="other"/></r>')
    rels <- function(css) {
        unlist(lapply(querySelectorAll(doc, css), xml_attr, "rel"))
    }

    expect_equal(rels('a[rel="nofollow"]'), "nofollow")
    expect_equal(rels('a[rel="nofollow" i]'), c("NoFollow", "nofollow"))
    expect_equal(rels('a[rel="NOFOLLOW" i]'), c("NoFollow", "nofollow"))
    expect_equal(rels('a[rel="nofollow" s]'), "nofollow")
    expect_equal(rels('a[rel^="NO" i]'), c("NoFollow", "nofollow"))
    expect_equal(rels('a[rel$="LOW" i]'), c("NoFollow", "nofollow"))
    expect_equal(rels('a[rel*="FOLL" i]'), c("NoFollow", "nofollow"))
})

test_that("querySelector methods handle invalid arguments", {
    skip_if_not_installed("xml2")
    library(xml2)
    doc <- read_xml('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>')

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
