# Representative document-querying checks for :has(), :where(), :nth-child(),
# adjacent-sibling, and :lang() against xml2 documents. Translation
# correctness for these constructs is the css-to-xpath crate's own concern;
# these just confirm each feature reaches a real document via querySelectorAll.

test_that(":has() matches elements with matching descendants/siblings", {
    skip_if_not_installed("xml2")
    library(xml2)

    doc <- read_xml(paste0(
        '<root>',
        '  <section id="s1"><div class="content"><p>Text</p></div></section>',
        '  <section id="s2"><div class="sidebar"><span>Text</span></div></section>',
        '  <div id="d1"><img id="i1"/></div>',
        '  <div id="d2"><span><img id="i2"/></span></div>',
        '</root>'
    ))
    get_ids <- function(css) xml_attr(querySelectorAll(doc, css), "id")

    expect_equal(get_ids("section:has(p)"), "s1")
    # leading combinator: only a direct child img counts
    expect_equal(get_ids("div:has(> img)"), "d1")
    expect_equal(get_ids("div:has(img)"), c("d1", "d2"))
})

test_that(":where() and :is() match any alternative with zero specificity effect on matching", {
    skip_if_not_installed("xml2")
    library(xml2)

    doc <- read_xml(paste0(
        '<root>',
        '  <div id="d1" class="content">Div</div>',
        '  <p id="p1" class="highlight">Para</p>',
        '  <span id="s1">Span</span>',
        '</root>'
    ))
    get_ids <- function(css) xml_attr(querySelectorAll(doc, css), "id")

    expect_equal(get_ids("*:where(div, p)"), c("d1", "p1"))
    expect_equal(get_ids("*:is(.highlight)"), "p1")
})

test_that(":nth-child() and :nth-last-child() count siblings positionally", {
    skip_if_not_installed("xml2")
    library(xml2)

    doc <- read_xml(paste0(
        '<root><ul>',
        '<li id="li1">1</li><li id="li2">2</li><li id="li3">3</li>',
        '</ul></root>'
    ))
    get_ids <- function(css) xml_attr(querySelectorAll(doc, css), "id")

    expect_equal(get_ids("li:nth-child(2)"), "li2")
    expect_equal(get_ids("li:nth-child(odd)"), c("li1", "li3"))
    expect_equal(get_ids("li:nth-last-child(1)"), "li3")
})

test_that("the adjacent sibling combinator matches only an immediately following sibling", {
    skip_if_not_installed("xml2")
    library(xml2)

    doc <- read_xml('<r><a id="a1">A</a><b id="b1">B</b><c id="c1">C</c></r>')
    get_ids <- function(css) xml_attr(querySelectorAll(doc, css), "id")

    expect_equal(get_ids("a + b"), "b1")
    expect_equal(length(querySelectorAll(doc, "a + c")), 0L)
})

test_that(":lang() matches elements by BCP 47 language range", {
    skip_if_not_installed("xml2")
    library(xml2)

    doc <- read_xml(paste0(
        '<test>',
        '<a id="first" xml:lang="en">a</a>',
        '<b id="second" xml:lang="en-US">b</b>',
        '<e id="fifth" xml:lang="fr">e</e>',
        '</test>'
    ))
    get_ids <- function(css) xml_attr(querySelectorAll(doc, css), "id")

    expect_equal(get_ids(':lang("EN")'), c("first", "second"))
    expect_equal(get_ids(":lang(fr)"), "fifth")
})
