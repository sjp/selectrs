# The parts of the querySelector* contract that hold for both packages.
# Behaviour that differs — how each package resolves prefixes, and what it
# warns about — is in test-querySelector-XML.R and -xml2.R.

forEachBackend("querySelector returns a single node or NULL", function(backend) {
    doc <- backend$parse('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>')
    root <- backend$findFirst(doc, "/*")

    expect_equal(backend$text(querySelector(doc, "a")),
                 backend$text(backend$findFirst(doc, "//a")))
    expect_equal(backend$text(querySelector(doc, "*", prefix = "")),
                 backend$text(backend$findFirst(backend$root(doc), "*")))
    expect_null(querySelector(doc, "d"))
    expect_equal(backend$text(querySelector(doc, "c")),
                 backend$text(backend$findFirst(doc, "//c")))

    # the same from the root element rather than the document
    expect_equal(backend$text(querySelector(root, "c")),
                 backend$text(backend$findFirst(doc, "//c")))
    expect_null(querySelector(root, "d"))
})

forEachBackend("querySelectorAll returns expected nodes", function(backend) {
    doc <- backend$parse('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>')
    root <- backend$findFirst(doc, "/*")

    expect_equal(backend$text(querySelectorAll(doc, "a")),
                 backend$text(backend$findAll(doc, "//a")))
    expect_equal(backend$text(querySelectorAll(doc, "*", prefix = "")),
                 backend$text(backend$findAll(backend$root(doc), "*")))
    expect_equal(backend$text(querySelectorAll(doc, "c")),
                 backend$text(backend$findAll(doc, "//c")))
    expect_equal(backend$text(querySelectorAll(root, "c")),
                 backend$text(backend$findAll(doc, "//c")))
})

forEachBackend("querySelectorAll returns an empty result for no match", function(backend) {
    doc <- backend$parse('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>')

    expect_equal(length(querySelectorAll(doc, "d")), 0L)
    expect_equal(backend$text(querySelectorAll(doc, "d")),
                 backend$text(backend$findAll(doc, "//d")))
})

forEachBackend("querySelector methods handle invalid arguments", function(backend) {
    doc <- backend$parse('<a><b id="#test"/><c class="ex"/><c class="xmp"/></a>')
    svg <- c(svg = "http://www.w3.org/2000/svg")

    selector_error <- "A valid selector (single character string) must be provided."
    expect_error(querySelector(doc), selector_error, fixed = TRUE)
    expect_error(querySelectorAll(doc), selector_error, fixed = TRUE)
    expect_error(querySelectorNS(doc), selector_error, fixed = TRUE)
    expect_error(querySelectorAllNS(doc), selector_error, fixed = TRUE)

    # selectors must be a single string, not a vector
    expect_error(querySelector(doc, c("b", "c")), selector_error, fixed = TRUE)
    expect_error(querySelectorAll(doc, c("b", "c")), selector_error, fixed = TRUE)
    expect_error(querySelectorNS(doc, c("b", "c"), svg), selector_error, fixed = TRUE)
    expect_error(querySelectorAllNS(doc, c("b", "c"), svg), selector_error, fixed = TRUE)
    expect_error(querySelectorAll(doc, character(0)), selector_error, fixed = TRUE)
    expect_error(querySelectorAll(doc, 1), selector_error, fixed = TRUE)
    expect_error(querySelectorAll(doc, NULL), selector_error, fixed = TRUE)

    namespace_error <- "A namespace must be provided."
    expect_error(querySelectorNS(doc, "a"), namespace_error, fixed = TRUE)
    expect_error(querySelectorNS(doc, "a", NULL), namespace_error, fixed = TRUE)
    expect_error(querySelectorNS(doc, "a", character(0)), namespace_error, fixed = TRUE)
    expect_error(querySelectorAllNS(doc, "a"), namespace_error, fixed = TRUE)
    expect_error(querySelectorAllNS(doc, "a", NULL), namespace_error, fixed = TRUE)
    expect_error(querySelectorAllNS(doc, "a", character(0)), namespace_error, fixed = TRUE)
})

forEachBackend("a named list works the same as a named character vector for ns", function(backend) {
    doc <- backend$parse('<svg xmlns="http://www.w3.org/2000/svg"><circle cx="10" cy="10" r="10"/></svg>')
    ns_chr <- c(svg = "http://www.w3.org/2000/svg")
    ns_list <- list(svg = "http://www.w3.org/2000/svg")

    expect_equal(backend$text(querySelector(doc, "svg|circle", ns = ns_list)),
                 backend$text(querySelector(doc, "svg|circle", ns = ns_chr)))
    expect_equal(backend$text(querySelectorAll(doc, "svg|circle", ns = ns_list)),
                 backend$text(querySelectorAll(doc, "svg|circle", ns = ns_chr)))
    expect_equal(backend$text(querySelectorNS(doc, "svg|circle", ns_list)),
                 backend$text(querySelectorNS(doc, "svg|circle", ns_chr)))
    expect_equal(backend$text(querySelectorAllNS(doc, "svg|circle", ns_list)),
                 backend$text(querySelectorAllNS(doc, "svg|circle", ns_chr)))

    # malformed namespace objects are still rejected
    expect_error(querySelectorAll(doc, "svg|circle", ns = list(svg = 1)),
                 "The values in the namespace object.*")
    expect_error(querySelectorAll(doc, "svg|circle", ns = c("http://www.w3.org/2000/svg")),
                 "The namespace object is missing some or all names.*")
    expect_error(querySelectorAll(doc, "svg|circle",
                                  ns = list(svg = c("http://www.w3.org/2000/svg", "extra"))),
                 "Each element in the namespace object must be a single character string.")
})

forEachBackend(":scope queries are anchored at the queried node", function(backend) {
    doc <- backend$parse(paste0(
        '<root>',
        '<section id="s1"><div id="d1"><div id="d2"/></div></section>',
        '<section id="s2"><div id="d3"/></section>',
        '</root>'
    ))
    s1 <- querySelector(doc, "#s1")

    # :scope is the queried node itself; combinators search relative to it
    expect_equal(backend$ids(querySelector(s1, ":scope")), "s1")
    expect_equal(backend$ids(querySelectorAll(s1, ":scope > div")), "d1")
    expect_equal(backend$ids(querySelectorAll(s1, ":scope div")), c("d1", "d2"))
    expect_equal(backend$ids(querySelector(s1, "section:scope")), "s1")
    expect_equal(length(querySelectorAll(s1, "div:scope")), 0L)
    # a plain query is evaluated relative to the node too, but includes
    # the node itself; :scope > anchors a child (not descendant) search
    expect_equal(backend$ids(querySelectorAll(s1, "div")), c("d1", "d2"))
    # sibling scope: the next sibling of s1 is s2
    expect_equal(backend$ids(querySelectorAll(s1, ":scope + section")), "s2")
    # a document is queried from its root element, so :scope on a document
    # is the root element
    expect_equal(backend$ids(querySelectorAll(doc, ":scope > section")),
                 c("s1", "s2"))
    expect_equal(length(querySelectorAll(doc, ":scope > body")), 0L)
    expect_equal(backend$elementName(querySelector(doc, ":scope")), "root")
})

forEachBackend("the *NS variants are scoped to the queried node", function(backend) {
    doc <- backend$parse(paste0(
        '<root xmlns:s="urn:s">',
        '<s:a id="outer"/>',
        '<wrap><s:a id="inner"/></wrap>',
        '</root>'
    ))
    ns <- c(s = "urn:s")
    wrap <- backend$findFirst(doc, "//wrap")

    expect_equal(backend$ids(querySelectorAllNS(wrap, "s|a", ns)), "inner")
    expect_equal(backend$ids(querySelectorNS(wrap, "s|a", ns)), "inner")
    expect_equal(backend$ids(querySelectorAllNS(backend$findAll(doc, "//wrap"),
                                                "s|a", ns)), "inner")
    # matching the un-namespaced functions given the same namespace
    expect_equal(backend$ids(querySelectorAll(wrap, "s|a", ns = ns)), "inner")

    # a query on the document still reaches everything
    expect_equal(backend$ids(querySelectorAllNS(doc, "s|a", ns)),
                 c("outer", "inner"))

    # the filter is descendant-or-self::, so the element it starts from can
    # itself match
    nsdoc <- backend$parse('<s:root xmlns:s="urn:s"><s:a id="a"/></s:root>')
    expect_equal(length(querySelectorAllNS(nsdoc, "s|root", ns)), 1L)
})

forEachBackend("a zero-length namespace skips the document's namespace map", function(backend) {
    doc <- backend$parse("<a><b id='1'/><c><b id='2'/></c></a>")
    node <- backend$findFirst(doc, "//c")
    nodes <- backend$findAll(doc, "//c")

    for (none in list(character(0), list())) {
        expect_equal(backend$ids(querySelectorAll(doc, "b", ns = none)), c("1", "2"))
        expect_equal(backend$ids(querySelector(doc, "b", ns = none)), "1")
        expect_equal(backend$ids(querySelectorAll(node, "b", ns = none)), "2")
        expect_equal(backend$ids(querySelector(node, "b", ns = none)), "2")
        expect_equal(backend$ids(querySelectorAll(nodes, "b", ns = none)), "2")
        expect_equal(backend$ids(querySelector(nodes, "b", ns = none)), "2")
        expect_equal(backend$ids(querySelectorAll(doc, "d", ns = none)), character())
        expect_null(querySelector(doc, "d", ns = none))
    }

    # a prefixed selector still resolves when the map is passed; what each
    # package does *without* one differs, and is pinned per backend
    nsdoc <- backend$parse('<r xmlns:s="urn:s"><s:b id="1"/></r>')
    expect_equal(backend$ids(querySelectorAll(nsdoc, "s|b", ns = c(s = "urn:s"))),
                 "1")

    # the *NS variants still demand a namespace
    expect_error(querySelectorAllNS(doc, "b", character(0)),
                 "A namespace must be provided.", fixed = TRUE)
    expect_error(querySelectorNS(doc, "b", list()),
                 "A namespace must be provided.", fixed = TRUE)
})
