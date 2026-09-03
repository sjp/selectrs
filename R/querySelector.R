# The four querySelector* generics, their default, XML
# (XMLInternalNode/XMLInternalDocument/HTMLInternalDocument/XMLNodeSet), and
# xml2 (xml_node/xml_nodeset/xml_missing) methods, plus the
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
#'
#' Queries may therefore be chained: a `querySelectorAll(doc, "table")` can
#' be followed by `querySelectorAll(tables, "tr")`, which searches each
#' matched table in turn. The selector is evaluated from each node of the
#' set, so a relative selector such as `":scope > a"` applies per node, and
#' a node that matches from more than one node of the set is returned only
#' once, at the position it first matched. An `xml_missing`, the result of
#' a failed [xml2::xml_find_first()], yields no matches rather than an
#' error.
#'
#' The `querySelectorNS` and `querySelectorAllNS` functions are convenience
#' functions for working with namespaced documents. They filter out all
#' content that does not belong within the given namespaces. Note that
#' elements searched for in a selector must then carry a namespace prefix,
#' e.g. `"svg|g"`.
#'
#' The namespace argument, `ns`, is passed on to [XML::getNodeSet()] or
#' [xml2::xml_find_all()] if it is necessary to use a namespace present
#' within the document. It can be ignored for content lacking a namespace.
#' For \pkg{xml2}, leaving it at `NULL` means the namespaces the document
#' declares are collected, with [xml2::xml_ns()], for every query; passing a
#' zero-length `ns` skips that walk of the document, which is worth doing in
#' a loop over a large document known to be un-namespaced.
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
#' For \pkg{xml2} the document is recognised however the query starts,
#' including from a node or a set of nodes of an HTML document. The
#' \pkg{XML} package, on the other hand, gives the nodes of an HTML
#' document the same class as those of an XML document, so only a query
#' starting from the document itself is recognised; pass
#' `translator = "html"` when querying from an \pkg{XML} node or
#' `XMLNodeSet`.
#'
#' The `:scope` pseudo-class refers to `doc` itself, so a query can be
#' anchored at the queried node: `querySelectorAll(node, ":scope > a")`
#' returns `node`'s `a` children. When `doc` is a document rather than a
#' node, queries are evaluated from its root element, so `:scope` matches
#' the root element. Because `:scope` anchors the expression at the
#' queried node, the `prefix` argument (including the namespace filter the
#' `*NS` variants build into it) does not apply to selectors led by
#' `:scope`.
#'
#' Errors raised by these functions are classed conditions; see the Errors
#' section of [css_to_xpath()].
#'
#' @param doc The XML document, node, or set of nodes to be evaluated
#'   against.
#' @param selector A selector used to query `doc`. This must be a single
#'   character string.
#' @param ns The namespace that the query will be filtered to: a named list
#'   or vector mapping namespace prefixes to namespace URIs. Both the
#'   prefixes and the URIs must be non-missing, non-empty character strings,
#'   and each prefix must be an XML name.
#'   Optional for the un-namespaced functions, where the default, `NULL`,
#'   uses the namespaces declared by the document itself, and a zero-length
#'   `ns` (`character(0)` or `list()`) uses none at all.
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
#'   <https://developer.mozilla.org/en-US/docs/Web/API/Document/querySelectorAll>.
#' @examples
#' if (requireNamespace("xml2", quietly = TRUE)) {
#'   exdoc <- xml2::read_xml('<a><b class="aclass"/><c id="anid"/></a>')
#'   querySelector(exdoc, "#anid")   # Returns the matching node
#'   querySelector(exdoc, ".aclass") # Returns the matching node
#'   querySelector(exdoc, "b, c")    # First match from grouped selection
#'   querySelectorAll(exdoc, "b, c") # Grouped selection
#'   querySelectorAll(exdoc, "b")    # A list of length one
#'   querySelector(exdoc, "d")       # No match
#'   querySelectorAll(exdoc, "d")    # No match
#'
#'   # A default namespace needs a prefix in the selector: xml2 names it d1
#'   nsdoc <- xml2::read_xml('<a xmlns="http://example.org"><b/></a>')
#'   querySelectorAll(nsdoc, "b")    # No match
#'   querySelectorAll(nsdoc, "d1|b") # The namespace xml_ns() named d1
#'   querySelectorAll(nsdoc, "*|b")  # Any namespace
#'
#'   # Queries can be chained, the second running from each node matched by
#'   # the first
#'   querySelectorAll(querySelectorAll(exdoc, "a"), "c")
#' }
#' @export
querySelector <- function(doc, selector, ns = NULL, ...) {
    UseMethod("querySelector", doc)
}

#' @rdname querySelector
#' @export
querySelectorAll <- function(doc, selector, ns = NULL, ...) {
    UseMethod("querySelectorAll", doc)
}

#' @rdname querySelector
#' @export
querySelectorNS <- function(doc, selector, ns,
                            prefix = "descendant-or-self::", ...) {
    UseMethod("querySelectorNS", doc)
}

#' @rdname querySelector
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

#' @export
querySelector.XMLInternalDocument <- function(doc, selector, ns = NULL, ...) {
    results <- querySelectorAll(doc, selector, ns, ...)
    if (length(results))
        results[[1]]
    else
        NULL
}

#' @export
querySelector.XMLInternalNode <- querySelector.XMLInternalDocument

#' @export
querySelector.XMLNodeSet <- querySelector.XMLInternalDocument

#' @export
querySelectorAll.XMLInternalNode <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
    xpath <- css_to_xpath(selector, ...)
    ns <- formatNS(ns)
    if (length(ns))
        XML::getNodeSet(doc, xpath, ns)
    else
        XML::getNodeSet(doc, xpath)
}

#' @export
querySelectorAll.XMLInternalDocument <- function(doc, selector, ns = NULL, ...) {
    doc <- XML::xmlRoot(doc)
    querySelectorAll(doc, selector, ns, ...)
}

# XML::htmlParse() gives a document the "HTMLInternalDocument" class, so an
# HTML document is recognised by dispatch. The nodes of such a document are
# plain XMLInternalNodes, indistinguishable from those of an XML document,
# so a query starting from a node (or a node set) is not recognised and
# keeps the generic translator.
#
# Only querySelectorAll() needs a method here: querySelector() and the two
# namespaced functions call the generic on the document itself, so they
# arrive back at this method.
#' @export
querySelectorAll.HTMLInternalDocument <- function(doc, selector, ns = NULL,
                                                  translator = "html", ...) {
    doc <- XML::xmlRoot(doc)
    querySelectorAll(doc, selector, ns, translator = translator, ...)
}

#' @export
querySelectorAll.XMLNodeSet <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
    xpath <- css_to_xpath(selector, ...)
    ns <- formatNS(ns)
    results <- lapply(doc, function(node) {
        if (length(ns))
            XML::getNodeSet(node, xpath, ns)
        else
            XML::getNodeSet(node, xpath)
    })
    results <- unlist(results, recursive = FALSE)
    if (is.null(results))
        results <- list()
    # A node matched from more than one node in the set is returned once, at
    # the position it was first matched, mirroring what xml2 does when given
    # a nodeset.
    structure(unique(results), class = "XMLNodeSet")
}

#' @export
querySelector.xml_node <- function(doc, selector, ns = NULL,
                                   translator = NULL, ...) {
    validateSelector(selector)
    ns <- if (is.null(ns)) xml2::xml_ns(doc) else formatNS(ns)
    translator <- defaultTranslator(translator, doc)
    xpath <- css_to_xpath(selector, translator = translator, ...)
    result <- xml2::xml_find_first(doc, xpath, ns)
    if (length(result))
        result
    else
        NULL
}

#' @export
querySelectorAll.xml_node <- function(doc, selector, ns = NULL,
                                      translator = NULL, ...) {
    validateSelector(selector)
    ns <- if (is.null(ns)) xml2::xml_ns(doc) else formatNS(ns)
    translator <- defaultTranslator(translator, doc)
    xpath <- css_to_xpath(selector, translator = translator, ...)
    xml2::xml_find_all(doc, xpath, ns)
}

#' @export
querySelector.xml_nodeset <- function(doc, selector, ns = NULL, ...) {
    results <- querySelectorAll(doc, selector, ns, ...)
    if (length(results))
        results[[1]]
    else
        NULL
}

#' @export
querySelectorAll.xml_nodeset <- function(doc, selector, ns = NULL,
                                         translator = NULL, ...) {
    validateSelector(selector)
    ns <- if (is.null(ns)) xml2::xml_ns(doc) else formatNS(ns)
    translator <- defaultTranslator(translator, doc)
    xpath <- css_to_xpath(selector, translator = translator, ...)
    # xml2 evaluates the expression from each node in turn, so a relative
    # selector (e.g. ":scope > a") applies per node, and a node matched more
    # than once is returned only once.
    xml2::xml_find_all(doc, xpath, ns)
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

# The translator for a query on the xml2 object 'doc' that did not name one.
# Users scraping HTML almost always want the "html" translator, so a
# document parsed as HTML gets it; everything else keeps the "generic" (XML)
# translator that css_to_xpath() defaults to.
#
# xml2 uses the same classes for HTML and XML content, so unlike the XML
# package the kind of document cannot be found by dispatch and is instead
# asked of libxml2 here. The document node of a document read by
# xml2::read_html() reports its type as "html_document", which is true for
# its nodes and node sets too. A node set may be empty, and so have no
# document to ask, in which case the query is generic.
defaultTranslator <- function(translator, doc) {
    if (!is.null(translator))
        return(translator)
    type <- tryCatch(xml2::xml_type(xml2::xml_parent(xml2::xml_root(doc))),
                     error = function(e) NA_character_)
    if (identical(type, "html_document"))
        "html"
    else
        "generic"
}

# xml2 does not export a constructor for an empty nodeset, but this is the
# structure it uses for one.
emptyNodeSet <- function() {
    structure(list(), class = "xml_nodeset")
}

validateSelector <- function(selector) {
    if (missing(selector) || !is.character(selector) || length(selector) != 1L)
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
    if (is.list(ns) && any(lengths(ns) != 1))
        argumentError("Each element in the namespace object must be a single character string.")
    # A zero-length namespace object asks for no namespace map at all, which
    # spares the xml2 methods the document walk xml_ns() would otherwise cost.
    if (!length(ns))
        return(character())
    nsNames <- names(ns)
    if (is.null(nsNames) || anyNA(nsNames) || !all(nzchar(nsNames)))
        argumentError("The namespace object is missing some or all names for each element in its collection.")
    badNames <- nsNames[!grepl(ncnamePattern, nsNames, perl = TRUE)]
    if (length(badNames))
        argumentError(paste0(
            "The namespace prefixes must be XML names, unlike ",
            paste0("\"", vapply(badNames, abbreviateValue, "", USE.NAMES = FALSE), "\"",
                   collapse = ", ")))
    ns <- unlist(ns)
    if (!is.character(ns))
        argumentError("The values in the namespace object must be a character vector.")
    if (anyNA(ns) || !all(nzchar(ns)))
        argumentError("The namespace URIs must be non-missing, non-empty character strings.")
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
