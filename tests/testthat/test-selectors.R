# Representative document-querying checks for :has(), :where(), :nth-child(),
# adjacent-sibling, and :lang(). Translation correctness for these constructs
# is the css-to-xpath crate's own concern; these just confirm each feature
# reaches a real document via querySelectorAll.

forEachBackend(":has() matches elements with matching descendants/siblings", function(backend) {
    doc <- backend$parse(paste0(
        '<root>',
        '  <section id="s1"><div class="content"><p>Text</p></div></section>',
        '  <section id="s2"><div class="sidebar"><span>Text</span></div></section>',
        '  <div id="d1"><img id="i1"/></div>',
        '  <div id="d2"><span><img id="i2"/></span></div>',
        '</root>'
    ))
    get_ids <- function(css) backend$ids(querySelectorAll(doc, css))

    expect_equal(get_ids("section:has(p)"), "s1")
    # leading combinator: only a direct child img counts
    expect_equal(get_ids("div:has(> img)"), "d1")
    expect_equal(get_ids("div:has(img)"), c("d1", "d2"))
})

forEachBackend(":where() and :is() match any alternative with zero specificity effect on matching", function(backend) {
    doc <- backend$parse(paste0(
        '<root>',
        '  <div id="d1" class="content">Div</div>',
        '  <p id="p1" class="highlight">Para</p>',
        '  <span id="s1">Span</span>',
        '</root>'
    ))
    get_ids <- function(css) backend$ids(querySelectorAll(doc, css))

    expect_equal(get_ids("*:where(div, p)"), c("d1", "p1"))
    expect_equal(get_ids("*:is(.highlight)"), "p1")
})

forEachBackend(":nth-child() and :nth-last-child() count siblings positionally", function(backend) {
    doc <- backend$parse(paste0(
        '<root><ul>',
        '<li id="li1">1</li><li id="li2">2</li><li id="li3">3</li>',
        '</ul></root>'
    ))
    get_ids <- function(css) backend$ids(querySelectorAll(doc, css))

    expect_equal(get_ids("li:nth-child(2)"), "li2")
    expect_equal(get_ids("li:nth-child(odd)"), c("li1", "li3"))
    expect_equal(get_ids("li:nth-last-child(1)"), "li3")
})

forEachBackend("the adjacent sibling combinator matches only an immediately following sibling", function(backend) {
    doc <- backend$parse('<r><a id="a1">A</a><b id="b1">B</b><c id="c1">C</c></r>')
    get_ids <- function(css) backend$ids(querySelectorAll(doc, css))

    expect_equal(get_ids("a + b"), "b1")
    expect_equal(length(querySelectorAll(doc, "a + c")), 0L)
})

forEachBackend(":lang() matches elements by BCP 47 language range", function(backend) {
    doc <- backend$parse(paste0(
        '<test>',
        '<a id="first" xml:lang="en">a</a>',
        '<b id="second" xml:lang="en-US">b</b>',
        '<e id="fifth" xml:lang="fr">e</e>',
        '</test>'
    ))
    get_ids <- function(css) backend$ids(querySelectorAll(doc, css))

    expect_equal(get_ids(':lang("EN")'), c("first", "second"))
    expect_equal(get_ids(":lang(fr)"), "fifth")
})

forEachBackend("querySelectorAll honours attribute case-sensitivity flags", function(backend) {
    doc <- backend$parse('<r><a rel="NoFollow"/><a rel="nofollow"/><a rel="other"/></r>')
    rels <- function(css) backend$attribute(querySelectorAll(doc, css), "rel")

    expect_equal(rels('a[rel="nofollow"]'), "nofollow")
    expect_equal(rels('a[rel="nofollow" i]'), c("NoFollow", "nofollow"))
})

forEachBackend(":required/:optional match per the HTML semantics", function(backend) {
    # Ground truth from browser document.querySelectorAll() on the same
    # markup: required/optional only apply to select, textarea, and the
    # input types that support the required attribute.
    doc <- backend$parse(paste0(
        '<form>',
        '<input id="text-req" required="required"/>',
        '<input id="text-opt"/>',
        '<input id="check-req" type="checkbox" required="required"/>',
        '<input id="hidden-req" type="hidden" required="required"/>',
        '<input id="hidden-opt" type="hidden"/>',
        '<input id="range-req" type="range" required="required"/>',
        '<input id="submit-req" type="submit" required="required"/>',
        '<select id="select-req" required="required"/>',
        '<select id="select-opt"/>',
        '<textarea id="textarea-req" required="required"/>',
        '<button id="button"/>',
        '<option id="option"/>',
        '</form>'
    ))

    expect_equal(backend$ids(querySelectorAll(doc, ":required", translator = "html")),
                 c("text-req", "check-req", "select-req", "textarea-req"))
    # The generic translator treats it as unmatchable runtime state.
    expect_equal(length(querySelectorAll(doc, ":required")), 0L)
})

forEachBackend(":empty matches what browsers match: whitespace counts, comments do not", function(backend) {
    # Browsers implement the Selectors Level 3 behaviour (the Level 4
    # draft's whitespace loosening has never shipped in any engine, as of
    # 2026), and selectr matches it: any text content, even whitespace
    # alone, makes an element non-empty; comment nodes are not content.
    doc <- backend$parse(paste0(
        '<root>',
        '<a id="truly"/>',
        '<a id="ws"> </a>',
        '<a id="nl">\n</a>',
        '<a id="text">x</a>',
        '<a id="child"><b/></a>',
        '<a id="comment"><!-- c --></a>',
        '</root>'
    ))

    expect_equal(backend$ids(querySelectorAll(doc, "a:empty")),
                 c("truly", "comment"))
})
