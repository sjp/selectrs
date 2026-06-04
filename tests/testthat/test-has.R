test_that(":has() works correctly with XML documents", {
    skip_if_not_installed("XML")
    library(XML)

    # Create test document
    html <- paste0(
        '<root>',
        '  <section id="s1">',
        '    <div class="content">',
        '      <p>Paragraph in section 1</p>',
        '    </div>',
        '  </section>',
        '  <section id="s2">',
        '    <div class="sidebar">',
        '      <span>Span in section 2</span>',
        '    </div>',
        '  </section>',
        '  <section id="s3">',
        '    <header>',
        '      <h1>Title</h1>',
        '    </header>',
        '  </section>',
        '  <article id="a1">',
        '    <p>Article paragraph</p>',
        '  </article>',
        '</root>'
    )

    doc <- xmlRoot(xmlParse(html))

    # Helper to get IDs
    get_ids <- function(css) {
        results <- querySelectorAll(doc, css)
        sapply(results, function(x) xmlGetAttr(x, "id"))
    }

    # Section containing a p element
    expect_equal(get_ids("section:has(p)"), "s1")

    # Section containing a div
    expect_equal(get_ids("section:has(div)"), c("s1", "s2"))

    # Section containing an h1
    expect_equal(get_ids("section:has(h1)"), "s3")

    # Section with div.content
    expect_equal(get_ids("section:has(div.content)"), "s1")

    # Section with div.sidebar
    expect_equal(get_ids("section:has(div.sidebar)"), "s2")

    # Any element containing a p
    # Note: XML returns root element too since it's also ancestor
    ids <- get_ids(":has(p)")
    expect_equal("s1" %in% ids && "a1" %in% ids, TRUE)

    # Multiple selectors: section with p OR span
    expect_equal(get_ids("section:has(p, span)"), c("s1", "s2"))

    # Chained :has() - section with both div and p
    expect_equal(get_ids("section:has(div):has(p)"), "s1")

    # :has() should not match the element itself
    expect_equal(length(querySelectorAll(doc, "p:has(p)")), 0)
})

test_that(":has() works correctly with xml2 documents", {
    skip_if_not_installed("xml2")
    library(xml2)

    # Create test document
    html <- paste0(
        '<root>',
        '  <section id="s1">',
        '    <div class="content">',
        '      <p>Paragraph in section 1</p>',
        '    </div>',
        '  </section>',
        '  <section id="s2">',
        '    <div class="sidebar">',
        '      <span>Span in section 2</span>',
        '    </div>',
        '  </section>',
        '  <section id="s3">',
        '    <header>',
        '      <h1>Title</h1>',
        '    </header>',
        '  </section>',
        '  <article id="a1">',
        '    <p>Article paragraph</p>',
        '  </article>',
        '</root>'
    )

    doc <- read_xml(html)

    # Helper to get IDs
    get_ids <- function(css) {
        results <- querySelectorAll(doc, css)
        xml_attr(results, "id")
    }

    # Section containing a p element
    expect_equal(get_ids("section:has(p)"), "s1")

    # Section containing a div
    expect_equal(get_ids("section:has(div)"), c("s1", "s2"))

    # Section containing an h1
    expect_equal(get_ids("section:has(h1)"), "s3")

    # Section with div.content
    expect_equal(get_ids("section:has(div.content)"), "s1")

    # Section with div.sidebar
    expect_equal(get_ids("section:has(div.sidebar)"), "s2")

    # Any element containing a p
    # Note: returns all ancestors including root
    ids <- get_ids(":has(p)")
    expect_equal("s1" %in% ids && "a1" %in% ids, TRUE)

    # Multiple selectors: section with p OR span
    expect_equal(get_ids("section:has(p, span)"), c("s1", "s2"))

    # Chained :has() - section with both div and p
    expect_equal(get_ids("section:has(div):has(p)"), "s1")

    # :has() should not match the element itself
    expect_equal(length(querySelectorAll(doc, "p:has(p)")), 0)
})

test_that(":has() handles edge cases correctly", {
    skip_if_not_installed("XML")
    library(XML)

    # Empty elements
    html1 <- '<root><div id="d1"></div><div id="d2"><p></p></div></root>'
    doc1 <- xmlRoot(xmlParse(html1))

    # Only d2 has a p descendant
    result1 <- querySelectorAll(doc1, "div:has(p)")
    expect_equal(length(result1), 1)
    expect_equal(xmlGetAttr(result1[[1]], "id"), "d2")

    # Nested :has()
    html2 <- paste0(
        '<root>',
        '  <section id="s1">',
        '    <article>',
        '      <div>',
        '        <p class="highlight">Text</p>',
        '      </div>',
        '    </article>',
        '  </section>',
        '  <section id="s2">',
        '    <article>',
        '      <p>Text</p>',
        '    </article>',
        '  </section>',
        '</root>'
    )
    doc2 <- xmlRoot(xmlParse(html2))

    # Nested :has() is invalid (selectors-4 excludes :has() from its
    # own argument grammar); the descendant form expresses the same match.
    expect_error(querySelectorAll(doc2, "section:has(article:has(div))"),
                 'Unable to parse the CSS selector "section:has(article:has(div))"',
                 fixed = TRUE)
    result2 <- querySelectorAll(doc2, "section:has(div)")
    expect_equal(length(result2), 1)
    expect_equal(xmlGetAttr(result2[[1]], "id"), "s1")

    # Section containing p.highlight
    result3 <- querySelectorAll(doc2, "section:has(p.highlight)")
    expect_equal(length(result3), 1)
    expect_equal(xmlGetAttr(result3[[1]], "id"), "s1")

    # :has() with universal selector
    html3 <- '<root><div id="d1"><span/></div><div id="d2"></div></root>'
    doc3 <- xmlRoot(xmlParse(html3))

    # Div that has any descendant
    result4 <- querySelectorAll(doc3, "div:has(*)")
    expect_equal(length(result4), 1)
    expect_equal(xmlGetAttr(result4[[1]], "id"), "d1")
})

test_that(":has() with leading combinators matches correctly", {
    skip_if_not_installed("xml2")
    library(xml2)

    # d1 has a child img; d2 has only a grandchild img; d3 has none but
    # is followed by a sibling img
    html <- paste0(
        '<root>',
        '  <div id="d1"><img id="i1"/></div>',
        '  <div id="d2"><span><img id="i2"/></span></div>',
        '  <div id="d3"></div>',
        '  <img id="i3"/>',
        '</root>'
    )
    doc <- read_xml(html)
    get_ids <- function(css) {
        results <- querySelectorAll(doc, css)
        xml_attr(results, "id")
    }

    # implied descendant: child and grandchild both count
    expect_equal(get_ids("div:has(img)"), c("d1", "d2"))
    # > child only: a grandchild img must not match, nor a sibling img
    expect_equal(get_ids("div:has(> img)"), "d1")
    expect_equal(get_ids("div:has(> span)"), "d2")

    # sibling document: a1 p1 a2 b1 p2
    html2 <- paste0(
        '<root>',
        '  <a id="a1"/><p id="p1"/><a id="a2"/><b id="b1"/><p id="p2"/>',
        '</root>'
    )
    doc2 <- read_xml(html2)
    get_ids2 <- function(css) {
        results <- querySelectorAll(doc2, css)
        xml_attr(results, "id")
    }

    # ~ subsequent sibling: both a elements precede a p
    expect_equal(get_ids2("a:has(~ p)"), c("a1", "a2"))
    # + next sibling: a1 is immediately followed by p1; a2 is followed
    # by b1, so it must not match
    expect_equal(get_ids2("a:has(+ p)"), "a1")
    expect_equal(get_ids2("a:has(+ b)"), "a2")
    expect_equal(get_ids2("b:has(~ p)"), "b1")
    # sibling forms look at siblings, not the subtree: da has a child p
    # but no sibling p, so it must not match either sibling form
    html3 <- paste0(
        '<root>',
        '  <section><div id="da"><p/></div><div id="db"/></section>',
        '  <section><div id="dc"/><p/></section>',
        '</root>'
    )
    doc3 <- read_xml(html3)
    ids3 <- xml_attr(querySelectorAll(doc3, "div:has(~ p)"), "id")
    expect_equal(ids3, "dc")
    ids4 <- xml_attr(querySelectorAll(doc3, "div:has(+ p)"), "id")
    expect_equal(ids4, "dc")

    # mixed relative list: child a OR subsequent-sibling p
    expect_equal(get_ids2("a:has(+ b, + p)"), c("a1", "a2"))
})

test_that(":has() works with querySelector (returns first match)", {
    skip_if_not_installed("xml2")
    library(xml2)

    html <- paste0(
        '<root>',
        '  <section id="s1"><p>First</p></section>',
        '  <section id="s2"><p>Second</p></section>',
        '  <section id="s3"><span>Third</span></section>',
        '</root>'
    )

    doc <- read_xml(html)

    # Should return first section with p
    result <- querySelector(doc, "section:has(p)")
    expect_equal(xml_attr(result, "id"), "s1")

    # Should return NULL when no match
    result_none <- querySelector(doc, "section:has(article)")
    expect_equal(result_none, NULL)
})
