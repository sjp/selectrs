# The four querySelector* generics, their default, XML
# (XMLInternalNode/XMLInternalDocument/XMLNodeSet), R-level XML tree
# (XMLDocument/XMLDocumentContent/XMLNode) and xml2
# (xml_node/xml_nodeset/xml_missing) methods, plus the
# formatNS/formatNSPrefix helpers. css_to_xpath() dispatches into the
# Rust core.

querySelector <- function(doc, selector, ns = NULL, ...) {
    UseMethod("querySelector", doc)
}

querySelectorAll <- function(doc, selector, ns = NULL, ...) {
    UseMethod("querySelectorAll", doc)
}

querySelectorNS <- function(doc, selector, ns,
                            prefix = "descendant-or-self::", ...) {
    UseMethod("querySelectorNS", doc)
}

querySelectorAllNS <- function(doc, selector, ns,
                               prefix = "descendant-or-self::", ...) {
    UseMethod("querySelectorAllNS", doc)
}

querySelector.default <- function(doc, selector, ns = NULL, ...) {
    argumentError("The object given to querySelector() is not an 'XML' or 'xml2' document or node.")
}

querySelectorAll.default <- function(doc, selector, ns = NULL, ...) {
    argumentError("The object given to querySelectorAll() is not an 'XML' or 'xml2' document or node.")
}

querySelectorNS.default <- function(doc, selector, ns,
                                    prefix = "descendant-or-self::", ...) {
    argumentError("The object given to querySelectorNS() is not an 'XML' or 'xml2' document or node.")
}

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

querySelector.XMLDocument <- function(doc, selector, ns = NULL, ...) {
    rLevelTreeError("querySelector")
}

querySelector.XMLDocumentContent <- querySelector.XMLDocument

querySelector.XMLNode <- querySelector.XMLDocument

querySelectorAll.XMLDocument <- function(doc, selector, ns = NULL, ...) {
    rLevelTreeError("querySelectorAll")
}

querySelectorAll.XMLDocumentContent <- querySelectorAll.XMLDocument

querySelectorAll.XMLNode <- querySelectorAll.XMLDocument

querySelectorNS.XMLDocument <- function(doc, selector, ns,
                                        prefix = "descendant-or-self::", ...) {
    rLevelTreeError("querySelectorNS")
}

querySelectorNS.XMLDocumentContent <- querySelectorNS.XMLDocument

querySelectorNS.XMLNode <- querySelectorNS.XMLDocument

querySelectorAllNS.XMLDocument <- function(doc, selector, ns,
                                           prefix = "descendant-or-self::",
                                           ...) {
    rLevelTreeError("querySelectorAllNS")
}

querySelectorAllNS.XMLDocumentContent <- querySelectorAllNS.XMLDocument

querySelectorAllNS.XMLNode <- querySelectorAllNS.XMLDocument

querySelector.XMLInternalNode <- function(doc, selector, ns = NULL,
                                          translator = NULL, ...) {
    query <- xmlQuery(doc, selector, ns, translator, ...)
    xmlFirstMatch(doc, query$xpath, query$ns)
}

querySelector.XMLInternalDocument <- function(doc, selector, ns = NULL, ...) {
    doc <- XML::xmlRoot(doc)
    querySelector(doc, selector, ns, ...)
}

# Each node of the set is queried in turn and the first match ends the
# search, which is the node querySelectorAll() would return first.
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

querySelectorAll.XMLInternalNode <- function(doc, selector, ns = NULL,
                                             translator = NULL, ...) {
    query <- xmlQuery(doc, selector, ns, translator, ...)
    xmlMatches(doc, query$xpath, query$ns)
}

querySelectorAll.XMLInternalDocument <- function(doc, selector, ns = NULL, ...) {
    doc <- XML::xmlRoot(doc)
    querySelectorAll(doc, selector, ns, ...)
}

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
querySelector.xml_node <- function(doc, selector, ns = NULL,
                                   translator = NULL, ...) {
    query <- xml2Query(doc, selector, ns, translator, ...)
    result <- xml2::xml_find_first(doc, query$xpath, query$ns)
    if (length(result))
        result
    else
        NULL
}

querySelectorAll.xml_node <- function(doc, selector, ns = NULL,
                                      translator = NULL, ...) {
    query <- xml2Query(doc, selector, ns, translator, ...)
    xml2::xml_find_all(doc, query$xpath, query$ns)
}

# As for XMLNodeSet above, the nodes are queried in turn and the first match
# ends the search.
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

querySelectorAll.xml_nodeset <- function(doc, selector, ns = NULL,
                                         translator = NULL, ...) {
    query <- xml2Query(doc, selector, ns, translator, ...)
    # xml2 evaluates the expression from each node in turn, so a relative
    # selector (e.g. ":scope > a") applies per node, and a node matched more
    # than once is returned only once.
    xml2::xml_find_all(doc, query$xpath, query$ns)
}

querySelector.xml_missing <- function(doc, selector, ns = NULL, ...) {
    validateSelector(selector)
    NULL
}

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

querySelectorNS.XMLInternalDocument <- querySelectorNSMethod

querySelectorNS.XMLInternalNode <- querySelectorNSMethod

querySelectorNS.XMLNodeSet <- querySelectorNSMethod

querySelectorNS.xml_node <- querySelectorNSMethod

querySelectorNS.xml_nodeset <- querySelectorNSMethod

querySelectorNS.xml_missing <- querySelectorNSMethod

querySelectorAllNS.XMLInternalDocument <- querySelectorAllNSMethod

querySelectorAllNS.XMLInternalNode <- querySelectorAllNSMethod

querySelectorAllNS.XMLNodeSet <- querySelectorAllNSMethod

querySelectorAllNS.xml_node <- querySelectorAllNSMethod

querySelectorAllNS.xml_nodeset <- querySelectorAllNSMethod

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
    # A prefix that is not an XML name splices straight into the generated
    # XPath, where it surfaces as a libxml2 syntax error over an expression
    # the caller never wrote, so the core judges these names by the rule it
    # applies to a prefix written in a selector. It reads a string as raw
    # bytes and requires UTF-8: a latin1-marked prefix would otherwise reach
    # it as "", and one whose declared bytes enc2utf8() cannot convert is no
    # more an XML name than what it was written as.
    nsNames <- enc2utf8(nsNames)
    valid <- validUTF8(nsNames)
    valid[valid] <- valid_ns_prefixes_rust(nsNames[valid])
    badNames <- nsNames[!valid]
    # Bytes that are not valid UTF-8 would travel into the message, where
    # they break the printing and matching of the condition carrying them;
    # iconv() writes them as <e9>-style escapes instead.
    if (length(badNames))
        argumentError(paste0("Namespace prefixes must be valid XML names ",
                             "(e.g. 'svg', not '",
                             iconv(badNames[1], "UTF-8", "UTF-8", sub = "byte"),
                             "')."))
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
