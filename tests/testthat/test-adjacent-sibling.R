# Document-querying blocks ported from selectr's tests/testthat/test-adjacent-sibling.R
# (sjp/selectr@9ed9bb2, by Simon Potter); the translation-level blocks of the
# same file were already absorbed into selectrs' test-translation.R during
# Phase 2. Adapted for testthat edition 3 (expect_equal instead of
# expect_that/equals, no context()), XML/xml2 guarded by
# skip_if_not_installed().

test_that("adjacent sibling combinator works correctly with querySelector", {
    skip_if_not_installed("XML")
    skip_if_not_installed("XML")
    library(XML)

    # Test with immediate adjacent siblings
    doc1 <- htmlParse('<html><body><a id="a1">A</a><b id="b1">B</b></body></html>')
    results1 <- querySelectorAll(doc1, "a + b")
    expect_equal(length(results1), 1)
    expect_equal(xmlGetAttr(results1[[1]], "id"), "b1")

    # Test with intervening element (should NOT match)
    doc2 <- htmlParse('<html><body><a id="a1">A</a><c>C</c><b id="b1">B</b></body></html>')
    results2 <- querySelectorAll(doc2, "a + b")
    expect_equal(length(results2), 0)

    # Test with attributes on right side
    doc3 <- htmlParse('<html><body>
        <a>Link1</a><b id="b1">B1</b>
        <a>Link2</a><b>B2</b>
    </body></html>')
    results3 <- querySelectorAll(doc3, "a + b[id]")
    expect_equal(length(results3), 1)
    expect_equal(xmlGetAttr(results3[[1]], "id"), "b1")

    # Test with classes on both sides
    doc4 <- htmlParse('<html><body>
        <a class="link">Link</a><b class="text">B1</b>
        <a>Link2</a><b class="text">B2</b>
    </body></html>')
    results4 <- querySelectorAll(doc4, "a.link + b.text")
    expect_equal(length(results4), 1)

    # Test with multiple adjacent pairs
    doc5 <- htmlParse('<html><body>
        <a>A1</a><b id="b1">B1</b>
        <a>A2</a><b id="b2">B2</b>
    </body></html>')
    results5 <- querySelectorAll(doc5, "a + b")
    expect_equal(length(results5), 2)
    expect_equal(xmlGetAttr(results5[[1]], "id"), "b1")
    expect_equal(xmlGetAttr(results5[[2]], "id"), "b2")
})

test_that("adjacent sibling maintains correct semantics", {
    skip_if_not_installed("XML")
    skip_if_not_installed("XML")
    library(XML)

    # Verify it only matches IMMEDIATE adjacent siblings
    doc <- htmlParse('<html><body>
        <section>
            <h1>Title</h1>
            <p id="p1">Immediate</p>
            <div>Intervening</div>
            <p id="p2">Not immediate</p>
        </section>
        <article>
            <h2>Subtitle</h2>
            <p id="p3">Immediate</p>
        </article>
    </body></html>')

    results <- querySelectorAll(doc, "h1 + p, h2 + p")
    expect_equal(length(results), 2)
    ids <- sapply(results, xmlGetAttr, "id")
    expect_true("p1" %in% ids)
    expect_true("p3" %in% ids)
    expect_false("p2" %in% ids)

    # Test that it respects element type
    doc2 <- htmlParse('<html><body>
        <a>Link</a><b>B</b><c>C</c>
    </body></html>')

    results_b <- querySelectorAll(doc2, "a + b")
    expect_equal(length(results_b), 1)
    expect_equal(xmlName(results_b[[1]]), "b")

    results_c <- querySelectorAll(doc2, "a + c")
    expect_equal(length(results_c), 0) # c is not immediately after a

    results_star <- querySelectorAll(doc2, "a + *")
    expect_equal(length(results_star), 1)
    expect_equal(xmlName(results_star[[1]]), "b")
})

test_that("adjacent sibling with pseudo-classes", {
    xpath <- function(css) {
        css_to_xpath(css, prefix = "")
    }

    # Adjacent sibling with pseudo-class on right
    expect_equal(xpath('h1 + p:first-child'), "h1/following-sibling::*[1][self::p][(count(preceding-sibling::*) = 0)]")

    # Adjacent sibling with nth-child
    expect_equal(xpath('h1 + p:nth-child(2)'), "h1/following-sibling::*[1][self::p][(count(preceding-sibling::*) = 1)]")
})
