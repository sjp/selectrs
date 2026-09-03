# The querySelector* API behaves the same over an XML-package tree and an
# xml2 tree, so the tests that query real documents are written once
# against a small backend object and run for each package. Only the calls
# the packages provide differ: parsing, a native XPath search to compare
# against, and reading a node's name, attributes and serialised form.
#
# Everything here is namespaced (XML::/xml2::) rather than attached, so a
# test body sees only the selectrs API and the backend it was handed;
# test-zzz-attached-packages.R enforces that.

# XML has no single class for "some nodes": a query gives back an
# XMLNodeSet, a single match an XMLInternalNode, and no match a NULL.
xmlNodeList <- function(x) {
    if (is.null(x)) list()
    else if (inherits(x, "XMLInternalNode")) list(x)
    else as.list(x)
}

# getNodeSet() given a document evaluates a relative axis against nothing,
# so the root element stands in for the document — which is what
# querySelectorAll() does with one anyway.
xmlFindAll <- function(x, xpath, ns = character()) {
    if (inherits(x, "XMLAbstractDocument"))
        x <- XML::xmlRoot(x)
    if (length(ns))
        XML::getNodeSet(x, xpath, ns)
    else
        XML::getNodeSet(x, xpath)
}

backends <- list(
    XML = list(
        name = "XML",
        parse = function(text) XML::xmlParse(text, asText = TRUE),
        parseHtml = function(text) XML::htmlParse(text, asText = TRUE),
        nodesetClass = "XMLNodeSet",
        # A query on an XML document is evaluated from its root element.
        root = function(doc) XML::xmlRoot(doc),
        findAll = xmlFindAll,
        findFirst = function(x, xpath, ns = character()) {
            found <- xmlFindAll(x, xpath, ns)
            if (length(found)) found[[1]] else NULL
        },
        nodes = xmlNodeList,
        serialise = function(node) XML::saveXML(node, file = NULL),
        # xmlGetAttr() gives NULL for an absent attribute; reporting NA
        # instead matches xml2, so both backends read the same way.
        attribute = function(x, name) {
            vapply(xmlNodeList(x), function(node) {
                found <- XML::xmlGetAttr(node, name)
                if (is.null(found)) NA_character_ else found
            }, character(1))
        },
        elementName = function(node) XML::xmlName(node)
    ),
    xml2 = list(
        name = "xml2",
        parse = function(text) xml2::read_xml(text),
        parseHtml = function(text) xml2::read_html(text),
        nodesetClass = "xml_nodeset",
        # xml2 evaluates a document query from the root element too, but
        # takes the document itself as the context node.
        root = function(doc) doc,
        findAll = function(x, xpath, ns = character()) {
            xml2::xml_find_all(x, xpath, ns)
        },
        findFirst = function(x, xpath, ns = character()) {
            found <- xml2::xml_find_first(x, xpath, ns)
            if (inherits(found, "xml_missing")) NULL else found
        },
        # as.list() on a single xml_node takes it apart rather than
        # wrapping it, so only a nodeset is unpacked that way.
        nodes = function(x) {
            if (is.null(x)) list()
            else if (inherits(x, "xml_nodeset")) as.list(x)
            else list(x)
        },
        serialise = function(node) as.character(node),
        attribute = function(x, name) {
            if (is.null(x)) character() else xml2::xml_attr(x, name)
        },
        elementName = function(node) xml2::xml_name(node)
    )
)

# The two shorthands every test uses: the ids of whatever a query returned,
# and its serialised form, both as a character vector however many nodes
# came back.
backends <- lapply(backends, function(backend) {
    backend$ids <- function(x) backend$attribute(x, "id")
    backend$text <- function(x) vapply(backend$nodes(x), backend$serialise,
                                       character(1))
    backend
})

# Run one test body per backend. `code` is a function of the backend, so
# the loop variable reaches it by argument rather than by scope.
forEachBackend <- function(desc, code) {
    for (backend in backends) {
        test_that(paste0(desc, " (", backend$name, ")"), {
            skip_if_not_installed(backend$name)
            code(backend)
        })
    }
}

# The small HTML document the translator tests query: an element whose name
# and attributes need case-insensitive matching, and the states the html
# translator's pseudo-classes look for. Shared by test-html-translator.R and
# the per-package files.
translatorHtml <- function() {
    paste0('<html><head><title>t</title></head><body>',
           '<DIV class="wrap" lang="en">',
           '<input type="checkbox" checked>',
           '<input type="text" disabled>',
           '<a href="u">l</a>',
           '</DIV></body></html>')
}

# The XHTML document the shakespeare tests query, shared by both backends.
shakespeareHtml <- function() {
    path <- test_path("shakespeare.html")
    readChar(path, file.size(path), useBytes = TRUE)
}
