\name{querySelectorAll}
\alias{querySelector}
\alias{querySelectorAll}
\alias{querySelectorNS}
\alias{querySelectorAllNS}
\title{
  Find nodes that match a group of CSS selectors in an XML tree
}
\description{
  The purpose of these functions is to mimic the functionality of the
  \code{querySelector} and \code{querySelectorAll} functions present in
  Internet browsers, so an XML tree can be succinctly queried for nodes
  matching a CSS selector. Namespaced variants \code{querySelectorNS}
  and \code{querySelectorAllNS} search relative to a given namespace.
}
\usage{
querySelector(doc, selector, ns = NULL, ...)
querySelectorAll(doc, selector, ns = NULL, ...)
querySelectorNS(doc, selector, ns,
                prefix = "descendant-or-self::", ...)
querySelectorAllNS(doc, selector, ns,
                   prefix = "descendant-or-self::", ...)
}
\arguments{
  \item{doc}{
    The XML document, node, or set of nodes to be evaluated against.
  }
  \item{selector}{
    A selector used to query \code{doc}. This must be a single
    non-missing character string.
  }
  \item{ns}{
    The namespace that the query will be filtered to: a named list or
    vector mapping namespace prefixes to namespace URIs. Both the
    prefixes and the URIs must be non-missing, non-empty character
    strings, and each prefix must be an XML name. Optional for the
    un-namespaced functions, where the default, \code{NULL}, uses the
    namespaces the queried document or node declares, and a zero-length
    \code{ns} (\code{character(0)} or \code{list()}) uses none at all.
  }
  \item{prefix}{
    The prefix to apply to the resulting XPath expression. The default
    or \code{""} are most commonly used. As in
    \code{\link{css_to_xpath}}, it is prepended verbatim and never
    validated.
  }
  \item{...}{
    Parameters to be passed on to \code{\link{css_to_xpath}}.
  }
}
\details{
  Methods are provided for documents, nodes and sets of nodes from both
  the \pkg{XML} package
  (\code{XMLInternalDocument}/\code{XMLInternalNode}/\code{XMLNodeSet})
  and the \pkg{xml2} package
  (\code{xml_node}/\code{xml_nodeset}/\code{xml_missing}); the matching
  package must be installed for the corresponding method to work. The
  document has to be one XPath can search:
  \code{\link[XML]{xmlTreeParse}} and \code{\link[XML]{htmlTreeParse}}
  build a tree of R lists instead, which is rejected with a message
  naming the parsers that do — \code{\link[XML]{xmlParse}} and
  \code{\link[XML]{htmlParse}}, or \code{useInternalNodes = TRUE}.

  The \code{querySelectorNS} and \code{querySelectorAllNS} functions are
  convenience functions for working with namespaced documents. They
  filter out all content that does not belong within the given
  namespaces. Note that elements searched for in a selector must then
  carry a namespace prefix, e.g. \code{"svg|g"}. The filter is relative
  to \code{doc}, so like the un-namespaced functions these search a
  node's own subtree rather than the whole document. A selector starting
  with \code{:scope} replaces the filter altogether (see below); such a
  selector is namespaced by its own prefixes, e.g.
  \code{":scope > svg|g"}.

  The namespace argument, \code{ns}, is passed on to
  \code{\link[XML]{getNodeSet}} or \code{\link[xml2]{xml_find_all}} if
  it is necessary to use a namespace present within the document. It can
  be ignored for content lacking a namespace, which is usually the case
  when using \code{querySelector} or \code{querySelectorAll}. The
  default, \code{NULL}, leaves each package to supply a map of its own:
  \pkg{xml2} collects the document's declarations with
  \code{\link[xml2]{xml_ns}} for every query, while \pkg{XML} takes
  \code{\link[XML]{getNodeSet}}'s default, the declarations carried by
  the element the query starts from — so a prefixed selector that
  resolves from a document may not resolve from a node deeper in it.

  A zero-length \code{ns} (\code{character(0)} or \code{list()})
  registers no namespaces at all with either package. That spares
  \pkg{xml2} the walk of the document, which is worth doing in a loop
  over a large document known to be un-namespaced, and it leaves a
  prefixed selector with nothing to resolve against: \pkg{xml2} warns
  and matches nothing, \pkg{XML} raises an error from libxml2. Passing
  the map yourself is the way to be sure of either. It is an error for
  \code{querySelectorNS} and \code{querySelectorAllNS}, which have
  nothing to filter to without a namespace.

  A document with a \emph{default} namespace — one declared as
  \code{xmlns="..."}, as XHTML, SVG and Atom documents are — needs its
  element names prefixed in the selector even though the markup does not
  prefix them: XPath 1.0 has no notion of a default namespace, so an
  unprefixed name only matches elements in no namespace at all, and a
  bare \code{"p"} finds nothing. With \pkg{xml2} the default
  \code{ns = NULL} collects the document's namespaces with
  \code{\link[xml2]{xml_ns}}, which names each default namespace
  \code{d1}, \code{d2}, and so on, so \code{"d1|p"} selects the \code{p}
  elements. \code{"*|p"} selects them whatever the prefix and works with
  \pkg{XML} too, as does naming the namespace yourself
  (\code{ns = c(x = "http://www.w3.org/1999/xhtml")}, then
  \code{"x|p"}). A document read as HTML, by
  \code{\link[XML]{htmlParse}} or \code{\link[xml2]{read_html}}, is not
  affected: libxml2's HTML parser puts elements in no namespace, so bare
  names match. The rule reaches inside \code{:is()}, \code{:where()},
  \code{:not()}, \code{:has()} and \code{of S} as well, so
  \code{":is(p)"} finds nothing wherever \code{"p"} does; prefix the
  names there too.

  Queries may be chained: as well as a document or a single node,
  \code{doc} may be a set of nodes, i.e. an \pkg{xml2}
  \code{xml_nodeset} or an \pkg{XML} \code{XMLNodeSet}, as returned by
  \code{querySelectorAll}, so a \code{querySelectorAll(doc, "table")}
  can be followed by \code{querySelectorAll(tables, "tr")}. The selector
  is evaluated from each node of the set in turn, so a relative selector
  such as \code{":scope > a"} applies per node, and a node that matches
  from more than one node of the set is returned only once, at the
  position it first matched. An \pkg{xml2} \code{xml_missing}, the
  result of a failed \code{\link[xml2]{xml_find_first}}, is also
  accepted, and yields no matches rather than an error.

  Selectors are translated with the \code{generic} (XML) translator
  unless a \code{translator} argument is given to be passed on to
  \code{\link{css_to_xpath}}, with one exception: a document parsed as
  HTML, by \code{\link[XML]{htmlParse}} or
  \code{\link[xml2]{read_html}}, is queried with the \code{html}
  translator, so that element and attribute names are matched
  case-insensitively and the pseudo-classes that depend on HTML
  semantics (\code{:checked}, \code{:disabled}, \code{:link}, and
  \code{:lang()} via the \code{lang} attribute) match as they do in a
  browser. Passing \code{translator} explicitly overrides this for
  either kind of document.

  The document is recognised however the query starts, including from a
  node or a set of nodes of an HTML document, so a chained query keeps
  the \code{html} translator. What has no document to consult is queried
  with the \code{generic} translator: an empty set of nodes, the
  \code{xml_missing} of a failed \code{\link[xml2]{xml_find_first}}, and
  a node built outside any document by \code{\link[XML]{newXMLNode}}.

  The \code{:scope} pseudo-class refers to \code{doc} itself, so a query
  can be anchored at the queried node:
  \code{querySelectorAll(node, ":scope > a")} returns \code{node}'s
  \code{a} children, where \code{querySelectorAll(node, "a")} would
  return all of its \code{a} descendants. \code{:scope} after a
  combinator or within a functional pseudo-class is an error (it cannot
  be expressed in XPath 1.0). Because \code{:scope} anchors the
  expression at the queried node, the \code{prefix} argument (including
  the namespace filter the \code{*NS} variants build into it) does not
  apply to selectors led by \code{:scope}.

  When \code{doc} is a whole document rather than a node, the queried
  node is taken to be the document's root element, so a bare
  \code{:scope} matches that root element and \code{":scope > x"}
  matches its \code{x} children. This differs from a browser's
  \code{document.querySelectorAll()}, where \code{:scope} on a document
  refers to the document itself: a bare \code{:scope} matches nothing
  there (the document is not an element), while \code{":scope > html"}
  matches the root element. To query starting from the root element
  itself rather than the document, pass the root node (e.g.
  \code{\link[XML]{xmlRoot}} or \code{\link[xml2]{xml_root}}) as
  \code{doc} instead of the document.
}
\value{
  For \code{querySelector}, the first matched node, or \code{NULL} when
  nothing matches. For \code{querySelectorAll}, a (possibly empty) list
  of matched nodes, of the same class the queried document's package
  uses: an \code{xml_nodeset} for \pkg{xml2} and an \code{XMLNodeSet}
  for \pkg{XML}. The \code{*NS} variants return the same types as their
  un-namespaced counterparts.
}
\section{Errors}{
  These functions propagate the same \code{selectrs_parse_error} and
  \code{selectrs_translation_error} conditions that
  \code{\link{css_to_xpath}} raises for a malformed or unsupported
  selector (see the Errors section of \code{?css_to_xpath} for their
  fields and for the selectr class names they also carry), plus
  \code{selectrs_argument_error} for a bad R-level argument: \code{doc}
  that is not an \pkg{XML} or \pkg{xml2} document, node, or node set;
  \code{selector} that is not a single non-missing character string; or
  \code{ns} that is not a named list or named character vector of
  non-empty strings whose names are valid XML names (or, for
  \code{querySelectorNS} and \code{querySelectorAllNS}, a missing or
  zero-length \code{ns}).
}
\references{
  CSS Selectors Level 4 \url{https://www.w3.org/TR/selectors-4/}, XPath
  \url{https://www.w3.org/TR/xpath/}, querySelectorAll
  \url{https://developer.mozilla.org/en-US/docs/Web/API/Document/querySelectorAll}
  and
  \url{https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall}.
}
\author{
  Simon Potter
}
\seealso{
  \code{\link{css_to_xpath}}, whose Errors section documents the
  condition classes' fields; \code{\link{selectors}} for the full
  selector-support reference.
}
\examples{
  # Every selectrs_error class (see the Errors section) propagates from
  # these functions; selectrs_argument_error also covers a 'doc' that is
  # not an XML or xml2 document, node, or node set.
  tryCatch(
    querySelectorAll("not a document", "a"),
    selectrs_argument_error = function(e) cat(conditionMessage(e), "\n")
  )

  # The XML and xml2 packages are both optional (Suggests), so each demo
  # below is guarded with requireNamespace() and runs only when that
  # package is installed.

  # Demo for working with the XML package
  if (requireNamespace("XML", quietly = TRUE)) {
    exdoc <- XML::xmlParse('<a><b class="aclass"/><c id="anid"/></a>')
    querySelector(exdoc, "#anid")   # Returns the matching node
    querySelector(exdoc, ".aclass") # Returns the matching node
    querySelector(exdoc, "b, c")    # First match from grouped selection
    querySelectorAll(exdoc, "b, c") # Grouped selection
    querySelectorAll(exdoc, "b")    # A list of length one
    querySelector(exdoc, "d")       # No match
    querySelectorAll(exdoc, "d")    # No match

    # Queries can be chained, the second search running from each node
    # matched by the first
    querySelectorAll(querySelectorAll(exdoc, "a"), "c")

    # Read in a document where two namespaces are being set:
    # SVG and MathML
    svgdoc <- XML::xmlParse(system.file("demos/svg-mathml.svg",
                                        package = "selectrs"))
    # Search for <script/> elements in the SVG namespace
    querySelectorNS(svgdoc, "svg|script",
                    c(svg = "http://www.w3.org/2000/svg"))
    querySelectorAllNS(svgdoc, "svg|script",
                       c(svg = "http://www.w3.org/2000/svg"))
    # MathML content is *within* SVG content,
    # search for <mtext> elements within the MathML namespace
    querySelectorNS(svgdoc, "math|mtext",
                    c(math = "http://www.w3.org/1998/Math/MathML"))
    querySelectorAllNS(svgdoc, "math|mtext",
                       c(math = "http://www.w3.org/1998/Math/MathML"))
    # Search for *both* SVG and MathML content
    querySelectorAllNS(svgdoc, "svg|script, math|mo",
                       c(svg = "http://www.w3.org/2000/svg",
                         math = "http://www.w3.org/1998/Math/MathML"))
  }

  # Demo for working with the xml2 package
  if (requireNamespace("xml2", quietly = TRUE)) {
    exdoc <- xml2::read_xml('<a><b class="aclass"/><c id="anid"/></a>')
    querySelector(exdoc, "#anid")   # Returns the matching node
    querySelector(exdoc, ".aclass") # Returns the matching node
    querySelector(exdoc, "b, c")    # First match from grouped selection
    querySelectorAll(exdoc, "b, c") # Grouped selection
    querySelectorAll(exdoc, "b")    # A nodeset of length one
    querySelector(exdoc, "d")       # No match
    querySelectorAll(exdoc, "d")    # No match

    # A default namespace needs a prefix in the selector: xml2 names it d1
    nsdoc <- xml2::read_xml('<a xmlns="http://example.org"><b/></a>')
    querySelectorAll(nsdoc, "b")    # No match
    querySelectorAll(nsdoc, "d1|b") # The namespace xml_ns() named d1
    querySelectorAll(nsdoc, "*|b")  # Any namespace

    # Queries can be chained, the second search running from each node
    # matched by the first
    querySelectorAll(querySelectorAll(exdoc, "a"), "c")

    # Read in a document where two namespaces are being set:
    # SVG and MathML
    svgdoc <- xml2::read_xml(system.file("demos/svg-mathml.svg",
                                         package = "selectrs"))
    # Search for <script/> elements in the SVG namespace
    querySelectorNS(svgdoc, "svg|script",
                    c(svg = "http://www.w3.org/2000/svg"))
    querySelectorAllNS(svgdoc, "svg|script",
                       c(svg = "http://www.w3.org/2000/svg"))
    # MathML content is *within* SVG content,
    # search for <mtext> elements within the MathML namespace
    querySelectorNS(svgdoc, "math|mtext",
                    c(math = "http://www.w3.org/1998/Math/MathML"))
    querySelectorAllNS(svgdoc, "math|mtext",
                       c(math = "http://www.w3.org/1998/Math/MathML"))
    # Search for *both* SVG and MathML content
    querySelectorAllNS(svgdoc, "svg|script, math|mo",
                       c(svg = "http://www.w3.org/2000/svg",
                         math = "http://www.w3.org/1998/Math/MathML"))
  }
}
