# The four querySelector* generics, their default, XML
# (XMLInternalNode/XMLInternalDocument/XMLNodeSet), R-level XML tree
# (XMLDocument/XMLDocumentContent/XMLNode) and xml2
# (xml_node/xml_nodeset/xml_missing) methods, plus the
# formatNS/formatNSPrefix helpers. css_to_xpath() dispatches into the
# Rust core.

#' Find nodes that match a group of CSS selectors in an XML tree
#'
#' The purpose of these functions is to mimic the functionality of the
#' `querySelector` and `querySelectorAll` functions present in Internet
#' browsers, so an XML tree can be succinctly queried for nodes matching a
#' CSS selector. Namespaced variants `querySelectorNS` and
#' `querySelectorAllNS` search relative to a given namespace.
#'
#' Methods are provided for documents, nodes and sets of nodes from both the
#' \pkg{XML} package (`XMLInternalDocument`/`XMLInternalNode`/`XMLNodeSet`)
#' and the \pkg{xml2} package (`xml_node`/`xml_nodeset`/`xml_missing`); the
#' matching package must be installed for the corresponding method to work.
#' The document has to be one XPath can search: [XML::xmlTreeParse()] and
#' [XML::htmlTreeParse()] build a tree of R lists instead, which is rejected
#' with a message naming the parsers that do — [XML::xmlParse()] and
#' [XML::htmlParse()], or `useInternalNodes = TRUE`.
#'
#' The `querySelectorNS` and `querySelectorAllNS` functions are convenience
#' functions for working with namespaced documents. They filter out all
#' content that does not belong within the given namespaces. Note that
#' elements searched for in a selector must then carry a namespace prefix,
#' e.g. `"svg|g"`. The filter is relative to `doc`, so like the
#' un-namespaced functions these search a node's own subtree rather than the
#' whole document. A selector starting with `:scope` replaces the filter
#' altogether (see below); such a selector is namespaced by its own
#' prefixes, e.g. `":scope > svg|g"`.
#'
#' The namespace argument, `ns`, is passed on to [XML::getNodeSet()] or
#' [xml2::xml_find_all()] if it is necessary to use a namespace present
#' within the document. It can be ignored for content lacking a namespace,
#' which is usually the case when using `querySelector` or
#' `querySelectorAll`. The default, `NULL`, leaves each package to supply a
#' map of its own: \pkg{xml2} collects the document's declarations with
#' [xml2::xml_ns()] for every query, while \pkg{XML} takes
#' [XML::getNodeSet()]'s default, the declarations carried by the element
#' the query starts from — so a prefixed selector that resolves from a
#' document may not resolve from a node deeper in it.
#'
#' A zero-length `ns` (`character(0)` or `list()`) registers no namespaces
#' at all with either package. That spares \pkg{xml2} the walk of the
#' document, which is worth doing in a loop over a large document known to
#' be un-namespaced, and it leaves a prefixed selector with nothing to
#' resolve against: \pkg{xml2} warns and matches nothing, \pkg{XML} raises
#' an error from libxml2. Passing the map yourself is the way to be sure of
#' either. It is an error for `querySelectorNS` and `querySelectorAllNS`,
#' which have nothing to filter to without a namespace.
#'
#' A document with a *default* namespace — one declared as
#' `xmlns="..."`, as XHTML, SVG and Atom documents are — needs its
#' element names prefixed in the selector even though the markup does not
#' prefix them: XPath 1.0 has no notion of a default namespace, so an
#' unprefixed name only matches elements in no namespace at all, and a
#' bare `"p"` finds nothing. With \pkg{xml2} the default `ns = NULL`
#' collects the document's namespaces with [xml2::xml_ns()], which names
#' each default namespace `d1`, `d2`, and so on, so `"d1|p"` selects the
#' `p` elements. `"*|p"` selects them whatever the prefix and works with
#' \pkg{XML} too, as does naming the namespace yourself
#' (`ns = c(x = "http://www.w3.org/1999/xhtml")`, then `"x|p"`). A
#' document read as HTML, by [XML::htmlParse()] or [xml2::read_html()],
#' is not affected: libxml2's HTML parser puts elements in no namespace,
#' so bare names match. The rule reaches inside `:is()`, `:where()`,
#' `:not()`, `:has()` and `of S` as well, so `":is(p)"` finds nothing
#' wherever `"p"` does; prefix the names there too.
#'
#' Queries may be chained: as well as a document or a single node, `doc`
#' may be a set of nodes, i.e. an \pkg{xml2} `xml_nodeset` or an \pkg{XML}
#' `XMLNodeSet`, as returned by `querySelectorAll`, so a
#' `querySelectorAll(doc, "table")` can be followed by
#' `querySelectorAll(tables, "tr")`. The selector is evaluated from each
#' node of the set in turn, so a relative selector such as `":scope > a"`
#' applies per node, and a node that matches from more than one node of the
#' set is returned only once, at the position it first matched. An
#' \pkg{xml2} `xml_missing`, the result of a failed
#' [xml2::xml_find_first()], is also accepted, and yields no matches rather
#' than an error.
#'
#' Selectors are translated with the `generic` (XML) translator unless a
#' `translator` argument is given to be passed on to [css_to_xpath()],
#' with one exception: a document parsed as HTML, by [XML::htmlParse()] or
#' [xml2::read_html()], is queried with the `html` translator, so that
#' element and attribute names are matched case-insensitively and the
#' pseudo-classes that depend on HTML semantics (`:checked`, `:disabled`,
#' `:link`, and `:lang()` via the `lang` attribute) match as they do in a
#' browser. Passing `translator` explicitly overrides this for either kind
#' of document.
#'
#' The document is recognised however the query starts, including from a
#' node or a set of nodes of an HTML document, so a chained query keeps
#' the `html` translator. What has no document to consult is queried with
#' the `generic` translator: an empty set of nodes, the `xml_missing` of a
#' failed [xml2::xml_find_first()], and a node built outside any document
#' by [XML::newXMLNode()].
#'
#' The `:scope` pseudo-class refers to `doc` itself, so a query can be
#' anchored at the queried node: `querySelectorAll(node, ":scope > a")`
#' returns `node`'s `a` children, where `querySelectorAll(node, "a")`
#' would return all of its `a` descendants. `:scope` after a combinator or
#' within a functional pseudo-class is an error (it cannot be expressed in
#' XPath 1.0). Because `:scope` anchors the expression at the queried
#' node, the `prefix` argument (including the namespace filter the `*NS`
#' variants build into it) does not apply to selectors led by `:scope`.
#'
#' When `doc` is a whole document rather than a node, the queried node is
#' taken to be the document's root element, so a bare `:scope` matches
#' that root element and `":scope > x"` matches its `x` children. This
#' differs from a browser's `document.querySelectorAll()`, where `:scope`
#' on a document refers to the document itself: a bare `:scope` matches
#' nothing there (the document is not an element), while `":scope > html"`
#' matches the root element. To query starting from the root element
#' itself rather than the document, pass the root node (e.g.
#' [XML::xmlRoot()] or [xml2::xml_root()]) as `doc` instead of the
#' document.
#'
#' @section Errors:
#' These functions propagate the same `selectrs_parse_error` and
#' `selectrs_translation_error` conditions that [css_to_xpath()] raises
#' for a malformed or unsupported selector (see the Errors section of
#' `?css_to_xpath` for their fields and for the selectr class names they
#' also carry), plus `selectrs_argument_error` for a bad R-level
#' argument: `doc` that is not an \pkg{XML} or \pkg{xml2} document, node,
#' or node set; `selector` that is not a single non-missing character
#' string; or `ns` that is not a named list or named character vector of
#' non-empty strings whose names are valid XML names (or, for
#' `querySelectorNS` and `querySelectorAllNS`, a missing or zero-length
#' `ns`).
#'
#' @param doc The XML document, node, or set of nodes to be evaluated
#'   against.
#' @param selector A selector used to query `doc`. This must be a single
#'   non-missing character string.
#' @param ns The namespace that the query will be filtered to: a named list
#'   or vector mapping namespace prefixes to namespace URIs. Both the
#'   prefixes and the URIs must be non-missing, non-empty character strings,
#'   and each prefix must be an XML name.
#'   Optional for the un-namespaced functions, where the default, `NULL`,
#'   uses the namespaces the queried document or node declares, and a
#'   zero-length `ns` (`character(0)` or `list()`) uses none at all.
#' @param prefix The prefix to apply to the resulting XPath expression. The
#'   default or `""` are most commonly used. As in [css_to_xpath()], it is
#'   prepended verbatim and never validated.
#' @param ... Parameters to be passed on to [css_to_xpath()].
#' @returns For `querySelector`, the first matched node, or `NULL` when
#'   nothing matches. For `querySelectorAll`, a (possibly empty) list of
#'   matched nodes, of the same class the queried document's package uses:
#'   an `xml_nodeset` for \pkg{xml2} and an `XMLNodeSet` for \pkg{XML}. The
#'   `*NS` variants return the same types as their un-namespaced
#'   counterparts.
#' @references CSS Selectors Level 4 <https://www.w3.org/TR/selectors-4/>,
#'   XPath <https://www.w3.org/TR/xpath/>, querySelectorAll
#'   <https://developer.mozilla.org/en-US/docs/Web/API/Document/querySelectorAll>
#'   and <https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall>.
#' @author Simon Potter
#' @seealso [css_to_xpath()], whose Errors section documents the condition
#'   classes' fields; \code{\link{selectors}} for the full selector-support reference.
#' @examples
#' # Every selectrs_error class (see the Errors section) propagates from
#' # these functions; selectrs_argument_error also covers a 'doc' that is
#' # not an XML or xml2 document, node, or node set.
#' tryCatch(
#'   querySelectorAll("not a document", "a"),
#'   selectrs_argument_error = function(e) cat(conditionMessage(e), "\n")
#' )
#'
#' # The XML and xml2 packages are both optional (Suggests), so each demo
#' # below is guarded with requireNamespace() and runs only when that
#' # package is installed.
#'
#' # Demo for working with the XML package
#' if (requireNamespace("XML", quietly = TRUE)) {
#'   exdoc <- XML::xmlParse('<a><b class="aclass"/><c id="anid"/></a>')
#'   querySelector(exdoc, "#anid")   # Returns the matching node
#'   querySelector(exdoc, ".aclass") # Returns the matching node
#'   querySelector(exdoc, "b, c")    # First match from grouped selection
#'   querySelectorAll(exdoc, "b, c") # Grouped selection
#'   querySelectorAll(exdoc, "b")    # A list of length one
#'   querySelector(exdoc, "d")       # No match
#'   querySelectorAll(exdoc, "d")    # No match
#'
#'   # Queries can be chained, the second search running from each node
#'   # matched by the first
#'   querySelectorAll(querySelectorAll(exdoc, "a"), "c")
#'
#'   # Read in a document where two namespaces are being set:
#'   # SVG and MathML
#'   svgdoc <- XML::xmlParse(system.file("demos/svg-mathml.svg",
#'                                       package = "selectrs"))
#'   # Search for <script/> elements in the SVG namespace
#'   querySelectorNS(svgdoc, "svg|script",
#'                   c(svg = "http://www.w3.org/2000/svg"))
#'   querySelectorAllNS(svgdoc, "svg|script",
#'                      c(svg = "http://www.w3.org/2000/svg"))
#'   # MathML content is *within* SVG content,
#'   # search for <mtext> elements within the MathML namespace
#'   querySelectorNS(svgdoc, "math|mtext",
#'                   c(math = "http://www.w3.org/1998/Math/MathML"))
#'   querySelectorAllNS(svgdoc, "math|mtext",
#'                      c(math = "http://www.w3.org/1998/Math/MathML"))
#'   # Search for *both* SVG and MathML content
#'   querySelectorAllNS(svgdoc, "svg|script, math|mo",
#'                      c(svg = "http://www.w3.org/2000/svg",
#'                        math = "http://www.w3.org/1998/Math/MathML"))
#' }
#'
#' # Demo for working with the xml2 package
#' if (requireNamespace("xml2", quietly = TRUE)) {
#'   exdoc <- xml2::read_xml('<a><b class="aclass"/><c id="anid"/></a>')
#'   querySelector(exdoc, "#anid")   # Returns the matching node
#'   querySelector(exdoc, ".aclass") # Returns the matching node
#'   querySelector(exdoc, "b, c")    # First match from grouped selection
#'   querySelectorAll(exdoc, "b, c") # Grouped selection
#'   querySelectorAll(exdoc, "b")    # A nodeset of length one
#'   querySelector(exdoc, "d")       # No match
#'   querySelectorAll(exdoc, "d")    # No match
#'
#'   # A default namespace needs a prefix in the selector: xml2 names it d1
#'   nsdoc <- xml2::read_xml('<a xmlns="http://example.org"><b/></a>')
#'   querySelectorAll(nsdoc, "b")    # No match
#'   querySelectorAll(nsdoc, "d1|b") # The namespace xml_ns() named d1
#'   querySelectorAll(nsdoc, "*|b")  # Any namespace
#'
#'   # Queries can be chained, the second search running from each node
#'   # matched by the first
#'   querySelectorAll(querySelectorAll(exdoc, "a"), "c")
#'
#'   # Read in a document where two namespaces are being set:
#'   # SVG and MathML
#'   svgdoc <- xml2::read_xml(system.file("demos/svg-mathml.svg",
#'                                        package = "selectrs"))
#'   # Search for <script/> elements in the SVG namespace
#'   querySelectorNS(svgdoc, "svg|script",
#'                   c(svg = "http://www.w3.org/2000/svg"))
#'   querySelectorAllNS(svgdoc, "svg|script",
#'                      c(svg = "http://www.w3.org/2000/svg"))
#'   # MathML content is *within* SVG content,
#'   # search for <mtext> elements within the MathML namespace
#'   querySelectorNS(svgdoc, "math|mtext",
#'                   c(math = "http://www.w3.org/1998/Math/MathML"))
#'   querySelectorAllNS(svgdoc, "math|mtext",
#'                      c(math = "http://www.w3.org/1998/Math/MathML"))
#'   # Search for *both* SVG and MathML content
#'   querySelectorAllNS(svgdoc, "svg|script, math|mo",
#'                      c(svg = "http://www.w3.org/2000/svg",
#'                        math = "http://www.w3.org/1998/Math/MathML"))
#' }
#' @name querySelectorAll
#' @rdname querySelectorAll
#' @export
querySelector <- function(doc, selector, ns = NULL, ...) {
    UseMethod("querySelector", doc)
}

#' @rdname querySelectorAll
#' @export
querySelectorAll <- function(doc, selector, ns = NULL, ...) {
    UseMethod("querySelectorAll", doc)
}

#' @rdname querySelectorAll
#' @export
querySelectorNS <- function(doc, selector, ns,
                            prefix = "descendant-or-self::", ...) {
    UseMethod("querySelectorNS", doc)
}

#' @rdname querySelectorAll
#' @export
querySelectorAllNS <- function(doc, selector, ns,
                               prefix = "descendant-or-self::", ...) {
    UseMethod("querySelectorAllNS", doc)
}

#' @export
querySelector.default <- function(doc, selector, ns = NULL, ...) {
    argumentError("The object given to querySelector() is not an 'XML' or 'xml2' document or node.")
}

#' @export
querySelectorAll.default <- function(doc, selector, ns = NULL, ...) {
    argumentError("The object given to querySelectorAll() is not an 'XML' or 'xml2' document or node.")
}

#' @export
querySelectorNS.default <- function(doc, selector, ns,
                                    prefix = "descendant-or-self::", ...) {
    argumentError("The object given to querySelectorNS() is not an 'XML' or 'xml2' document or node.")
}

#' @export
querySelectorAllNS.default <- function(doc, selector, ns,
                                    prefix = "descendant-or-self::", ...) {
    argumentError("The object given to querySelectorAllNS() is not an 'XML' or 'xml2' document or node.")
}

# XML::xmlTreeParse() and XML::htmlTreeParse() return a tree of R lists
# rather than a libxml2 document, and XPath can only be evaluated over the
# latter. Such a tree is an 'XML' document, so the default method's message
# would send the reader looking for the wrong problem; point at the parsers
# that give a searchable document instead.
rLevelTreeError <- function(fname) {
    argumentError(paste0(
        "The object given to ", fname, "() is an R-level 'XML' tree, which ",
        "cannot be searched with XPath. Re-parse the document with ",
        "XML::xmlParse() or XML::htmlParse() (equivalently, with ",
        "useInternalNodes = TRUE)."))
}

#' @export
querySelector.XMLDocument <- function(doc, selector, ns = NULL, ...) {
    rLevelTreeError("querySelector")
}

#' @export
querySelector.XMLDocumentContent <- querySelector.XMLDocument

#' @export
querySelector.XMLNode <- querySelector.XMLDocument

#' @export
querySelectorAll.XMLDocument <- function(doc, selector, ns = NULL, ...) {
    rLevelTreeError("querySelectorAll")
}

#' @export
querySelectorAll.XMLDocumentContent <- querySelectorAll.XMLDocument

#' @export
querySelectorAll.XMLNode <- querySelectorAll.XMLDocument

#' @export
querySelectorNS.XMLDocument <- function(doc, selector, ns,
                                        prefix = "descendant-or-self::", ...) {
    rLevelTreeError("querySelectorNS")
}

#' @export
querySelectorNS.XMLDocumentContent <- querySelectorNS.XMLDocument

#' @export
querySelectorNS.XMLNode <- querySelectorNS.XMLDocument

#' @export
querySelectorAllNS.XMLDocument <- function(doc, selector, ns,
                                           prefix = "descendant-or-self::",
                                           ...) {
    rLevelTreeError("querySelectorAllNS")
}

#' @export
querySelectorAllNS.XMLDocumentContent <- querySelectorAllNS.XMLDocument

#' @export
querySelectorAllNS.XMLNode <- querySelectorAllNS.XMLDocument

#' @export
querySelector.XMLInternalNode <- function(doc, selector, ns = NULL,
                                          translator = NULL, ...) {
    query <- xmlQuery(doc, selector, ns, translator, ...)
    xmlFirstMatch(doc, query$xpath, query$ns)
}

#' @export
querySelector.XMLInternalDocument <- function(doc, selector, ns = NULL, ...) {
    doc <- XML::xmlRoot(doc)
    querySelector(doc, selector, ns, ...)
}

# Each node of the set is queried in turn and the first match ends the
# search, which is the node querySelectorAll() would return first.
#' @export
querySelector.XMLNodeSet <- function(doc, selector, ns = NULL,
                                     translator = NULL, ...) {
    query <- xmlQuery(doc, selector, ns, translator, ...)
    for (i in seq_along(doc)) {
        result <- xmlFirstMatch(doc[[i]], query$xpath, query$ns)
        if (!is.null(result))
            return(result)
    }
    NULL
}

#' @export
querySelectorAll.XMLInternalNode <- function(doc, selector, ns = NULL,
                                             translator = NULL, ...) {
    query <- xmlQuery(doc, selector, ns, translator, ...)
    xmlMatches(doc, query$xpath, query$ns)
}

#' @export
querySelectorAll.XMLInternalDocument <- function(doc, selector, ns = NULL, ...) {
    doc <- XML::xmlRoot(doc)
    querySelectorAll(doc, selector, ns, ...)
}

#' @export
querySelectorAll.XMLNodeSet <- function(doc, selector, ns = NULL,
                                        translator = NULL, ...) {
    query <- xmlQuery(doc, selector, ns, translator, ...)
    results <- lapply(doc, xmlMatches, query$xpath, query$ns)
    results <- unlist(results, recursive = FALSE)
    if (is.null(results))
        results <- list()
    # A node matched from more than one node in the set is returned once, at
    # the position it was first matched, mirroring what xml2 does when given
    # a nodeset.
    structure(unique(results), class = "XMLNodeSet")
}

# xml2::xml_find_first() stops at the first match, which is the shortcut the
# XML methods above get from a parenthesised expression and a [1] predicate;
# neither has to find every match to return one.
#' @export
querySelector.xml_node <- function(doc, selector, ns = NULL,
                                   translator = NULL, ...) {
    query <- xml2Query(doc, selector, ns, translator, ...)
    result <- xml2::xml_find_first(doc, query$xpath, query$ns)
    if (length(result))
        result
    else
        NULL
}

#' @export
querySelectorAll.xml_node <- function(doc, selector, ns = NULL,
                                      translator = NULL, ...) {
    query <- xml2Query(doc, selector, ns, translator, ...)
    xml2::xml_find_all(doc, query$xpath, query$ns)
}

# As for XMLNodeSet above, the nodes are queried in turn and the first match
# ends the search.
#' @export
querySelector.xml_nodeset <- function(doc, selector, ns = NULL,
                                      translator = NULL, ...) {
    query <- xml2Query(doc, selector, ns, translator, ...)
    for (i in seq_along(doc)) {
        result <- xml2::xml_find_first(doc[[i]], query$xpath, query$ns)
        if (length(result))
            return(result)
    }
    NULL
}

#' @export
querySelectorAll.xml_nodeset <- function(doc, selector, ns = NULL,
                                         translator = NULL, ...) {
    query <- xml2Query(doc, selector, ns, translator, ...)
    # xml2 evaluates the expression from each node in turn, so a relative
    # selector (e.g. ":scope > a") applies per node, and a node matched more
    # than once is returned only once.
    xml2::xml_find_all(doc, query$xpath, query$ns)
}

#' @export
querySelector.xml_missing <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
    NULL
}

#' @export
querySelectorAll.xml_missing <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
    emptyNodeSet()
}

# The namespaced variants are the same for both packages: they filter the
# prefix to the given namespaces and hand back to the plain generic, which
# dispatches to the method for whichever kind of node it was given.
querySelectorNSMethod <- function(doc, selector, ns,
                                  prefix = "descendant-or-self::", ...) {
    validateSelector(selector)
    if (missing(ns) || !length(ns))
        argumentError("A namespace must be provided.")
    ns <- formatNS(ns)
    prefix <- formatNSPrefix(ns, prefix)
    querySelector(doc, selector, ns, prefix = prefix, ...)
}

querySelectorAllNSMethod <- function(doc, selector, ns,
                                     prefix = "descendant-or-self::", ...) {
    validateSelector(selector)
    if (missing(ns) || !length(ns))
        argumentError("A namespace must be provided.")
    ns <- formatNS(ns)
    prefix <- formatNSPrefix(ns, prefix)
    querySelectorAll(doc, selector, ns, prefix = prefix, ...)
}

#' @export
querySelectorNS.XMLInternalDocument <- querySelectorNSMethod

#' @export
querySelectorNS.XMLInternalNode <- querySelectorNSMethod

#' @export
querySelectorNS.XMLNodeSet <- querySelectorNSMethod

#' @export
querySelectorNS.xml_node <- querySelectorNSMethod

#' @export
querySelectorNS.xml_nodeset <- querySelectorNSMethod

#' @export
querySelectorNS.xml_missing <- querySelectorNSMethod

#' @export
querySelectorAllNS.XMLInternalDocument <- querySelectorAllNSMethod

#' @export
querySelectorAllNS.XMLInternalNode <- querySelectorAllNSMethod

#' @export
querySelectorAllNS.XMLNodeSet <- querySelectorAllNSMethod

#' @export
querySelectorAllNS.xml_node <- querySelectorAllNSMethod

#' @export
querySelectorAllNS.xml_nodeset <- querySelectorAllNSMethod

#' @export
querySelectorAllNS.xml_missing <- querySelectorAllNSMethod

# The translator for a query that did not name one. Users scraping HTML
# almost always want the "html" translator, so a document parsed as HTML
# gets it; everything else keeps the "generic" (XML) translator that
# css_to_xpath() defaults to.
#
# Neither package distinguishes HTML from XML content by class alone (XML
# classes only the document, not its nodes), so libxml2 is asked instead,
# by way of the owning document of whatever node the query starts from.
# That keeps the translator across a chained query, where only the first
# call sees the document. A node built outside any document, and an empty
# node set, have nothing to ask and are queried as XML.
#
# The document node of a document read by xml2::read_html() reports its
# type as "html_document", and so do its nodes and node sets.
xml2Translator <- function(translator, doc) {
    if (!is.null(translator))
        return(translator)
    type <- tryCatch(xml2::xml_type(xml2::xml_parent(xml2::xml_root(doc))),
                     error = function(e) NA_character_)
    if (identical(type, "html_document"))
        "html"
    else
        "generic"
}

# The XML package has no equivalent of xml_root(), but the "/" step reaches
# the owning document from any node that has one, and htmlParse() gives
# that document node the "XMLHTMLDocumentNode" class.
xmlTranslator <- function(translator, doc) {
    if (!is.null(translator))
        return(translator)
    if (inherits(doc, "XMLNodeSet")) {
        if (!length(doc))
            return("generic")
        doc <- doc[[1L]]
    }
    docNode <- tryCatch(XML::getNodeSet(doc, "/")[[1L]],
                        error = function(e) NULL)
    if (inherits(docNode, "XMLHTMLDocumentNode"))
        "html"
    else
        "generic"
}

# The first step shared by the xml2 methods: xml2 wants the namespaces as an
# argument to every query, and takes the document's own when the caller named
# none.
xml2Query <- function(doc, selector, ns, translator, ...) {
    validateSelector(selector)
    translator <- xml2Translator(translator, doc)
    list(xpath = css_to_xpath(selector, translator = translator, ...),
         ns = if (is.null(ns)) xml2::xml_ns(doc) else formatNS(ns))
}

# The same for the XML methods. querySelector() and querySelectorAll() differ
# only in what they then ask libxml2 for, so a query over a node set
# translates the selector once for the whole set rather than once per node.
xmlQuery <- function(doc, selector, ns, translator, ...) {
    validateSelector(selector)
    translator <- xmlTranslator(translator, doc)
    list(xpath = css_to_xpath(selector, translator = translator, ...),
         ns = formatNS(ns))
}

# XML::getNodeSet() supplies a default `namespaces` argument of its own,
# the declarations carried by the node it is given, so leaving the map to
# the package has to be an absent argument rather than a NULL one. A
# zero-length `ns`, which formatNS() gives back as an empty character
# vector, is passed on as the empty map it is, leaving a prefixed selector
# with nothing to resolve against.
xmlMatches <- function(node, xpath, ns) {
    if (is.null(ns))
        XML::getNodeSet(node, xpath)
    else
        XML::getNodeSet(node, xpath, ns)
}

# The first node the expression matches, or NULL. A positional predicate
# applies to a node set in document order, so parenthesising the whole
# expression and taking [1] picks out the same node as the first of the full
# result, without the XML package wrapping each of the other matches in an R
# object on the way to discarding it.
xmlFirstMatch <- function(node, xpath, ns) {
    results <- xmlMatches(node, paste0("(", xpath, ")[1]"), ns)
    if (length(results))
        results[[1]]
    else
        NULL
}

# xml2 does not export a constructor for an empty nodeset, but this is the
# structure it uses for one.
emptyNodeSet <- function() {
    structure(list(), class = "xml_nodeset")
}

validateSelector <- function(selector) {
    if (missing(selector) || !is.character(selector) || length(selector) != 1L ||
        is.na(selector))
        argumentError("A valid selector (single character string) must be provided.")
}

# A prefix that is not an XML name splices straight into the generated
# XPath, where it surfaces as a libxml2 syntax error over an expression the
# caller never wrote. The pattern approximates NCName (combining and
# extender characters are not admitted) and is deliberately Unicode-aware,
# since libxml2 accepts a non-ASCII prefix.
ncnamePattern <- "^[\\p{L}_][\\p{L}\\p{Nd}._-]*$"

# Takes a named vector or list and gives a named vector back
formatNS <- function(ns) {
    if (is.null(ns))
        return(NULL)
    if (!is.list(ns) && !is.character(ns))
        argumentError("A namespace object must be either a named list or a named character vector.")
    # A zero-length namespace object asks for no namespace map at all, which
    # spares the xml2 methods the document walk xml_ns() would otherwise cost.
    if (!length(ns))
        return(character())
    nsNames <- names(ns)
    if (is.null(nsNames) || anyNA(nsNames) || !all(nzchar(nsNames)))
        argumentError(paste0("The namespace object must be a named list or ",
                             "character vector; every element needs a ",
                             "non-empty name."))
    badNames <- nsNames[!grepl(ncnamePattern, nsNames, perl = TRUE)]
    if (length(badNames))
        argumentError(paste0("Namespace prefixes must be valid XML names ",
                             "(e.g. 'svg', not '", badNames[1], "')."))
    if (is.list(ns) && any(lengths(ns) != 1))
        argumentError("Each element in the namespace object must be a single character string.")
    ns <- unlist(ns)
    if (!is.character(ns))
        argumentError("The values in the namespace object must be a character vector.")
    if (anyNA(ns) || !all(nzchar(ns)))
        argumentError(paste0("The values in the namespace object must be ",
                             "non-missing, non-empty strings."))
    names(ns) <- nsNames
    ns
}

# The namespace filter is relative to the queried node, so that a query
# starting from a node searches that node's subtree rather than the whole
# document.
formatNSPrefix <- function(ns, prefix) {
    filters <- paste0("descendant-or-self::", names(ns), ":*", collapse = "|")
    prefix <- paste0("(", filters, ")/", prefix)
    prefix
}
