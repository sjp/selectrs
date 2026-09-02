# The four querySelector* generics, their default, XML
# (XMLInternalNode/XMLInternalDocument/XMLNodeSet), and xml2
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
#' @param doc The XML document, node, or set of nodes to be evaluated
#'   against.
#' @param selector A selector used to query `doc`. This must be a single
#'   character string.
#' @param ns The namespace that the query will be filtered to: a named list
#'   or vector mapping namespace prefixes to namespace URIs. Optional for
#'   the un-namespaced functions.
#' @param prefix The prefix to apply to the resulting XPath expression. The
#'   default or `""` are most commonly used.
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
    stop("The object given to querySelector() is not an 'XML' or 'xml2' document or node.")
}

#' @export
querySelectorAll.default <- function(doc, selector, ns = NULL, ...) {
    stop("The object given to querySelectorAll() is not an 'XML' or 'xml2' document or node.")
}

#' @export
querySelectorNS.default <- function(doc, selector, ns,
                                    prefix = "descendant-or-self::", ...) {
    stop("The object given to querySelectorNS() is not an 'XML' or 'xml2' document or node.")
}

#' @export
querySelectorAllNS.default <- function(doc, selector, ns,
                                    prefix = "descendant-or-self::", ...) {
    stop("The object given to querySelectorAllNS() is not an 'XML' or 'xml2' document or node.")
}

#' @export
querySelector.XMLInternalDocument <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
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
    if (!is.null(ns)) {
        ns <- formatNS(ns)
        XML::getNodeSet(doc, xpath, ns)
    } else {
        XML::getNodeSet(doc, xpath)
    }
}

#' @export
querySelectorAll.XMLInternalDocument <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
    doc <- XML::xmlRoot(doc)
    querySelectorAll(doc, selector, ns, ...)
}

#' @export
querySelectorAll.XMLNodeSet <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
    xpath <- css_to_xpath(selector, ...)
    if (!is.null(ns))
        ns <- formatNS(ns)
    results <- lapply(doc, function(node) {
        if (is.null(ns))
            XML::getNodeSet(node, xpath)
        else
            XML::getNodeSet(node, xpath, ns)
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
querySelectorNS.XMLInternalDocument <- function(doc, selector, ns,
                                                prefix = "descendant-or-self::", ...) {
    validateSelector(selector)
    if (missing(ns) || !length(ns))
        stop("A namespace must be provided.")
    ns <- formatNS(ns)
    prefix <- formatNSPrefix(ns, prefix)
    querySelector(doc, selector, ns, prefix = prefix, ...)
}

#' @export
querySelectorNS.XMLInternalNode <- querySelectorNS.XMLInternalDocument

#' @export
querySelectorNS.XMLNodeSet <- querySelectorNS.XMLInternalDocument

#' @export
querySelectorAllNS.XMLInternalDocument <- function(doc, selector, ns,
                                                   prefix = "descendant-or-self::", ...) {
    validateSelector(selector)
    if (missing(ns) || !length(ns))
        stop("A namespace must be provided.")
    ns <- formatNS(ns)
    prefix <- formatNSPrefix(ns, prefix)
    querySelectorAll(doc, selector, ns, prefix = prefix, ...)
}

#' @export
querySelectorAllNS.XMLInternalNode <- querySelectorAllNS.XMLInternalDocument

#' @export
querySelectorAllNS.XMLNodeSet <- querySelectorAllNS.XMLInternalDocument

#' @export
querySelector.xml_node <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
    if (is.null(ns))
        ns <- xml2::xml_ns(doc)
    else
        ns <- formatNS(ns)
    xpath <- css_to_xpath(selector, ...)
    result <- xml2::xml_find_first(doc, xpath, ns)
    if (length(result))
        result
    else
        NULL
}

#' @export
querySelectorAll.xml_node <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
    if (is.null(ns))
        ns <- xml2::xml_ns(doc)
    else
        ns <- formatNS(ns)
    xpath <- css_to_xpath(selector, ...)
    xml2::xml_find_all(doc, xpath, ns)
}

#' @export
querySelector.xml_nodeset <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
    results <- querySelectorAll(doc, selector, ns, ...)
    if (length(results))
        results[[1]]
    else
        NULL
}

#' @export
querySelectorAll.xml_nodeset <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
    if (is.null(ns))
        ns <- xml2::xml_ns(doc)
    else
        ns <- formatNS(ns)
    xpath <- css_to_xpath(selector, ...)
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

#' @export
querySelectorNS.xml_node <- function(doc, selector, ns,
                                     prefix = "descendant-or-self::", ...) {
    validateSelector(selector)
    if (missing(ns) || is.null(ns) || !length(ns))
        stop("A namespace must be provided.")
    ns <- formatNS(ns)
    prefix <- formatNSPrefix(ns, prefix)
    querySelector(doc, selector, ns, prefix = prefix, ...)
}

#' @export
querySelectorNS.xml_nodeset <- querySelectorNS.xml_node

#' @export
querySelectorNS.xml_missing <- querySelectorNS.xml_node

#' @export
querySelectorAllNS.xml_node <- function(doc, selector, ns,
                                        prefix = "descendant-or-self::", ...) {
    validateSelector(selector)
    if (missing(ns) || is.null(ns) || !length(ns))
        stop("A namespace must be provided.")
    ns <- formatNS(ns)
    prefix <- formatNSPrefix(ns, prefix)
    querySelectorAll(doc, selector, ns, prefix = prefix, ...)
}

#' @export
querySelectorAllNS.xml_nodeset <- querySelectorAllNS.xml_node

#' @export
querySelectorAllNS.xml_missing <- querySelectorAllNS.xml_node

# xml2 does not export a constructor for an empty nodeset, but this is the
# structure it uses for one.
emptyNodeSet <- function() {
    structure(list(), class = "xml_nodeset")
}

validateSelector <- function(selector) {
    if (missing(selector) || !is.character(selector) || length(selector) != 1L)
        stop("A valid selector (single character string) must be provided.")
}

# Takes a named vector or list and gives a named vector back
formatNS <- function(ns) {
    if (is.null(ns))
        return(NULL)
    if (!is.list(ns) && !is.character(ns))
        stop("A namespace object must be either a named list or a named character vector.")
    if (is.list(ns) && any(lengths(ns) != 1))
        stop("Each element in the namespace object must be a single character string.")
    nsNames <- names(ns)
    if (is.null(nsNames) || anyNA(nsNames) || !all(nzchar(nsNames)))
        stop("The namespace object is missing some or all names for each element in its collection.")
    ns <- unlist(ns)
    if (!is.character(ns))
        stop("The values in the namespace object must be a character vector.")
    names(ns) <- nsNames
    ns
}

formatNSPrefix <- function(ns, prefix) {
    filters <- paste0("//", names(ns), ":*", collapse = "|")
    prefix <- paste0("(", filters, ")/", prefix)
    prefix
}
