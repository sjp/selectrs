# Document-querying blocks ported from selectr's tests/testthat/test-namespaces.R
# (sjp/selectr@9ed9bb2, by Simon Potter); the translation-level blocks of the
# same file were already absorbed into selectrs' test-translation.R during
# Phase 2. Adapted for testthat edition 3 (expect_equal instead of
# expect_that/equals, no context()), XML/xml2 guarded by
# skip_if_not_installed().

test_that("namespace selectors match correct elements", {
    skip_if_not_installed("xml2")

    doc <- xml2::read_xml(paste0(
        '<r xmlns:svg="http://www.w3.org/2000/svg" a="x">',
        '<e>plain</e><svg:e svg:a="y">svg</svg:e></r>'))
    ns <- xml2::xml_ns(doc)
    matches <- function(sel) {
        nodes <- xml2::xml_find_all(doc, css_to_xpath(sel, prefix = "//"), ns)
        xml2::xml_name(nodes, ns)
    }

    expect_equal(matches("*|e"), c("e", "svg:e"))
    expect_equal(matches("|e"), "e")
    expect_equal(matches("|*"), c("r", "e"))
    expect_equal(matches("*|*"), c("r", "e", "svg:e"))
    expect_equal(matches("svg|e"), "svg:e")
    expect_equal(matches("[*|a]"), c("r", "svg:e"))
    expect_equal(matches("[|a]"), "r")
})
