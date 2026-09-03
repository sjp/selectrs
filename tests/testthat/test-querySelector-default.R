test_that("querySelector methods present an error on non-XML/xml2 objects", {
    expect_error(querySelector(list()), "The object given to querySelector.*")
    expect_error(querySelectorAll(list()), "The object given to querySelector.*")
    expect_error(querySelectorNS(list()), "The object given to querySelector.*")
    expect_error(querySelectorAllNS(list()), "The object given to querySelector.*")
})

test_that("an R-level XML tree is reported as one", {
    skip_if_not_installed("XML")
    # xmlTreeParse() and htmlTreeParse() build a tree of R lists rather than
    # a document XPath can search, so the message names the parsers that do
    # instead of denying that the object is an XML document at all.
    trees <- list(XML::xmlTreeParse("<a><b/></a>", asText = TRUE),
                  XML::htmlTreeParse("<a><b/></a>", asText = TRUE),
                  XML::xmlRoot(XML::xmlTreeParse("<a><b/></a>", asText = TRUE)))
    expect_equal(vapply(trees, function(tree) class(tree)[1L], ""),
                 c("XMLDocument", "XMLDocumentContent", "XMLNode"))

    ns <- c(a = "urn:a")
    calls <- list(
        querySelector = function(tree) querySelector(tree, "b"),
        querySelectorAll = function(tree) querySelectorAll(tree, "b"),
        querySelectorNS = function(tree) querySelectorNS(tree, "b", ns),
        querySelectorAllNS = function(tree) querySelectorAllNS(tree, "b", ns))
    for (tree in trees) {
        for (fname in names(calls)) {
            e <- tryCatch(calls[[fname]](tree), error = identity)
            expect_identical(class(e), c("selectrs_argument_error",
                                         "selectrs_error", "error", "condition"))
            expect_equal(conditionMessage(e), paste0(
                "The object given to ", fname, "() is an R-level 'XML' tree, ",
                "which cannot be searched with XPath. Re-parse the document ",
                "with XML::xmlParse() or XML::htmlParse() (equivalently, with ",
                "useInternalNodes = TRUE)."))
        }
    }

    # the same document parsed into the internal form is queried as usual
    doc <- XML::xmlTreeParse("<a><b id='1'/></a>", asText = TRUE,
                             useInternalNodes = TRUE)
    expect_equal(XML::xmlGetAttr(querySelector(doc, "b"), "id"), "1")
})
