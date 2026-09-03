# Querying the result of a query: a node set is a valid starting point, and
# the selector is applied to each of its nodes in turn. What only one
# package offers — an xml_missing to query — is in
# test-querySelector-xml2.R.

chainDoc <- '<html><body>
  <table id="t1"><tr><td class="a">1</td><td>2</td></tr><tr><td>3</td></tr></table>
  <table id="t2"><tr><td class="a">4</td></tr></table>
  <p><td>outside</td></p>
</body></html>'

forEachBackend("node sets can be queried", function(backend) {
    doc <- backend$parse(chainDoc)

    tables <- querySelectorAll(doc, "table")
    expect_true(inherits(tables, backend$nodesetClass))
    expect_equal(length(tables), 2)

    cells <- querySelectorAll(tables, "td")
    expect_true(inherits(cells, backend$nodesetClass))
    expect_equal(backend$text(cells),
                 backend$text(backend$findAll(doc, "//table//td")))

    # A node matched from more than one node in the set appears once
    expect_equal(length(querySelectorAll(querySelectorAll(doc, "table, tr"),
                                         "td")), 4)

    # querySelector() gives back the first match across the whole set
    expect_equal(backend$text(querySelector(tables, "td")),
                 backend$text(backend$findFirst(doc, "//table//td")))
    expect_null(querySelector(tables, "div"))
})

forEachBackend(":scope on a node set is applied per node", function(backend) {
    doc <- backend$parse('<a><x><b id="1"/><c><b id="2"/></c></x><y><b id="3"/></y></a>')

    kids <- querySelectorAll(doc, "x, y")
    expect_equal(backend$ids(querySelectorAll(kids, ":scope > b")),
                 c("1", "3"))
    expect_equal(backend$ids(querySelectorAll(kids, "b")), c("1", "2", "3"))
})

forEachBackend("querying an empty node set gives an empty node set",
               function(backend) {
    doc <- backend$parse(chainDoc)
    empty <- querySelectorAll(doc, "nosuchelement")
    expect_equal(length(empty), 0)

    res <- querySelectorAll(empty, "td")
    expect_true(inherits(res, backend$nodesetClass))
    expect_equal(length(res), 0)
    expect_null(querySelector(empty, "td"))
})

forEachBackend("namespaced queries work on node sets", function(backend) {
    svg <- c(svg = "http://www.w3.org/2000/svg")
    doc <- backend$parse(paste0(
        '<svg xmlns="http://www.w3.org/2000/svg">',
        '<g><circle id="1"/></g><g><circle id="2"/></g>',
        '</svg>'))

    gs <- querySelectorAllNS(doc, "svg|g", svg)
    expect_equal(length(gs), 2)

    expect_equal(backend$ids(querySelectorAll(gs, "svg|circle", ns = svg)),
                 c("1", "2"))
    expect_equal(backend$ids(querySelector(gs, "svg|circle", ns = svg)), "1")
    expect_equal(backend$ids(querySelectorAllNS(gs, "svg|circle", svg)),
                 c("1", "2"))
    expect_equal(backend$ids(querySelectorNS(gs, "svg|circle", svg)), "1")
})

forEachBackend("node set methods validate their arguments", function(backend) {
    doc <- backend$parse(chainDoc)
    tables <- querySelectorAll(doc, "table")

    expect_error(querySelectorAll(tables, c("td", "tr")),
                 "A valid selector .*must be provided")
    expect_error(querySelectorNS(tables, "td"), "A namespace must be provided.")
    expect_error(querySelectorAllNS(tables, "td"),
                 "A namespace must be provided.")
})
