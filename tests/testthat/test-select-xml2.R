test_that("selection works correctly on a large barrage of tests", {
    HTML_IDS <- paste0(
        c("<html id=\"html\"><head>", "  <link id=\"link-href\" href=\"foo\" />",
          "  <link id=\"link-nohref\" />", "</head><body>", "<div id=\"outer-div\">",
          " <a id=\"name-anchor\" name=\"foo\"></a>", " <a id=\"tag-anchor\" rel=\"tag\" href=\"http://localhost/foo\">link</a>",
          " <a id=\"nofollow-anchor\" rel=\"nofollow\" href=\"https://example.org\">",
          "    link</a>", " <ol id=\"first-ol\" class=\"a b c\">", "   <li id=\"first-li\">content</li>",
          "   <li id=\"second-li\" lang=\"En-us\">", "     <div id=\"li-div\">",
          "     </div>", "   </li>", "   <li id=\"third-li\" class=\"ab c\"></li>",
          "   <li id=\"fourth-li\" class=\"ab", "c\"></li>", "   <li id=\"fifth-li\"></li>",
          "   <li id=\"sixth-li\"></li>", "   <li id=\"seventh-li\">  </li>",
          " </ol>", " <p id=\"paragraph\">", "   <b id=\"p-b\">hi</b> <em id=\"p-em\">there</em>",
          "   <b id=\"p-b2\">guy</b>", "   <input type=\"checkbox\" id=\"checkbox-unchecked\" />",
          "   <input type=\"checkbox\" id=\"checkbox-disabled\" disabled=\"\" />",
          "   <input type=\"text\" id=\"text-checked\" checked=\"checked\" />",
          "   <input type=\"hidden\" />", "   <input type=\"hidden\" disabled=\"disabled\" />",
          "   <input type=\"checkbox\" id=\"checkbox-checked\" checked=\"checked\" />",
          "   <input type=\"checkbox\" id=\"checkbox-disabled-checked\"",
          "          disabled=\"disabled\" checked=\"checked\" />", "   <fieldset id=\"fieldset\" disabled=\"disabled\">",
          "     <input type=\"checkbox\" id=\"checkbox-fieldset-disabled\" />",
          "     <input type=\"hidden\" />", "   </fieldset>", " </p>",
          " <ol id=\"second-ol\">", " </ol>", " <map name=\"dummymap\">",
          "   <area shape=\"circle\" coords=\"200,250,25\" href=\"foo.html\" id=\"area-href\" />",
          "   <area shape=\"default\" id=\"area-nohref\" />", " </map>",
          "</div>", "<div id=\"foobar-div\" foobar=\"ab bc", "cde\"><span id=\"foobar-span\"></span></div>",
          "</body></html>"), collapse = "\n")

    skip_if_not_installed("xml2")
    library(xml2)
    document <- read_xml(HTML_IDS)
    select_ids <- function(selector, html_only) {
        translator <- if (html_only) "html" else "generic"
        xpath <- css_to_xpath(selector, translator = translator)
        items <- xml_find_all(document, xpath)
        n <- length(items)
        if (!n)
            return(NULL)
        result <- character(n)
        for (i in seq_len(n)) {
            element <- items[[i]]
            tmp <- xml_attr(element, "id")
            if (is.na(tmp))
                tmp <- "nil"
            result[i] <- tmp
        }
        result
    }

    pcss <- function(main, selectors = NULL, html_only = FALSE) {
        result <- select_ids(main, html_only)
        if (!is.null(selectors) && length(selectors)) {
            n <- length(selectors)
            for (i in seq_len(n)) {
                tmp_res <- select_ids(selectors[i], html_only = html_only)
                if (!is.null(result) && !is.null(tmp_res) &&
                    !identical(tmp_res, result))
                    stop("Difference between results of selectors")
            }
        }
        result
    }

    all_ids <- pcss('*')
    expect_equal(all_ids[1:6], c('html', 'nil', 'link-href', 'link-nohref', 'nil', 'outer-div'))
    expect_equal(tail(all_ids, 1), 'foobar-span')
    expect_equal(pcss('div'), c('outer-div', 'li-div', 'foobar-div'))
    expect_equal(pcss('DIV', html_only = TRUE), c('outer-div', 'li-div', 'foobar-div'))  # case-insensitive in HTML
    expect_equal(pcss('div div'), 'li-div')
    expect_equal(pcss('div, div div'), c('outer-div', 'li-div', 'foobar-div'))
    expect_equal(pcss('a[name]'), 'name-anchor')
    expect_equal(pcss('a[NAme]', html_only = TRUE), 'name-anchor') # case-insensitive in HTML:
    expect_equal(pcss('a[rel]'), c('tag-anchor', 'nofollow-anchor'))
    expect_equal(pcss('a[rel="tag"]'), 'tag-anchor')
    expect_equal(pcss('a[href*="localhost"]'), 'tag-anchor')
    expect_equal(pcss('a[href*=""]'), NULL)
    expect_equal(pcss('a[href^="http"]'), c('tag-anchor', 'nofollow-anchor'))
    expect_equal(pcss('a[href^="http:"]'), 'tag-anchor')
    expect_equal(pcss('a[href^=""]'), NULL)
    expect_equal(pcss('a[href$="org"]'), 'nofollow-anchor')
    expect_equal(pcss('a[href$=""]'), NULL)
    expect_equal(pcss('div[foobar~="bc"]', 'div[foobar~="cde"]'), 'foobar-div')
    expect_equal(pcss('[foobar~="ab bc"]', c('[foobar~=""]', '[foobar~=" \t"]')), NULL)
    expect_equal(pcss('div[foobar~="cd"]'), NULL)
    expect_equal(pcss('*[lang|="En"]', '[lang|="En-us"]'), 'second-li')
    # Attribute values are case sensitive
    expect_equal(pcss('*[lang|="en"]', '[lang|="en-US"]'), NULL)
    expect_equal(pcss('*[lang|="e"]'), NULL)
    # ... :lang() is not.
    expect_equal(pcss(':lang("EN")', '*:lang(en-US)', html_only = TRUE), c('second-li', 'li-div'))
    expect_equal(pcss(':lang("e")', html_only = TRUE), NULL)
    expect_equal(pcss('li:nth-child(-n)'), NULL)
    expect_equal(pcss('li:nth-child(n)'), c('first-li', 'second-li', 'third-li', 'fourth-li', 'fifth-li', 'sixth-li', 'seventh-li'))
    expect_equal(pcss('li:nth-child(3)'), 'third-li')
    expect_equal(pcss('li:nth-child(10)'), NULL)
    expect_equal(pcss('li:nth-child(2n)', c('li:nth-child(even)', 'li:nth-child(2n+0)')), c('second-li', 'fourth-li', 'sixth-li'))
    expect_equal(pcss('li:nth-child(+2n+1)', 'li:nth-child(odd)'), c('first-li', 'third-li', 'fifth-li', 'seventh-li'))
    expect_equal(pcss('li:nth-child(2n+4)'), c('fourth-li', 'sixth-li'))
    expect_equal(pcss('li:nth-child(3n+1)'), c('first-li', 'fourth-li', 'seventh-li'))
    expect_equal(pcss('li:nth-child(-n+3)'), c('first-li', 'second-li', 'third-li'))
    expect_equal(pcss('li:nth-child(-2n+4)'), c('second-li', 'fourth-li'))
    expect_equal(pcss('li:nth-last-child(0)'), NULL)
    expect_equal(pcss('li:nth-last-child(1)'), 'seventh-li')
    expect_equal(pcss('li:nth-last-child(2n)', 'li:nth-last-child(even)'), c('second-li', 'fourth-li', 'sixth-li'))
    expect_equal(pcss('li:nth-last-child(2n+2)'), c('second-li', 'fourth-li', 'sixth-li'))
    expect_equal(pcss('ol:first-of-type'), 'first-ol')
    expect_equal(pcss('ol:nth-child(1)'), NULL)
    expect_equal(pcss('ol:nth-of-type(2)'), 'second-ol')
    expect_equal(pcss('ol:nth-last-of-type(1)'), 'second-ol')
    expect_equal(pcss('span:only-child'), 'foobar-span')
    expect_equal(pcss('li div:only-child'), 'li-div')
    expect_equal(pcss('div *:only-child'), c('li-div', 'foobar-span'))
    #self.assertRaises(ExpressionError, pcss, 'p *:only-of-type')
    expect_equal(pcss('p:only-of-type'), 'paragraph')
    expect_equal(pcss('a:empty', 'a:EMpty'), 'name-anchor')
    expect_equal(pcss('li:empty'), c('third-li', 'fourth-li', 'fifth-li', 'sixth-li'))
    expect_equal(pcss(':root', 'html:root'), 'html')
    expect_equal(pcss('li:root', '* :root'), NULL)
    expect_equal(pcss('.a', c('.b', '*.a', 'ol.a')), 'first-ol')
    expect_equal(pcss('.c', '*.c'), c('first-ol', 'third-li', 'fourth-li'))
    expect_equal(pcss('ol *.c', c('ol li.c', 'li ~ li.c', 'ol > li.c')), c('third-li', 'fourth-li'))
    expect_equal(pcss('#first-li', c('li#first-li', '*#first-li')), 'first-li')
    expect_equal(pcss('li div', c('li > div', 'div div')), 'li-div')
    expect_equal(pcss('div > div'), NULL)
    expect_equal(pcss('div>.c', 'div > .c'), 'first-ol')
    expect_equal(pcss('div + div'), 'foobar-div')
    expect_equal(pcss('a ~ a'), c('tag-anchor', 'nofollow-anchor'))
    expect_equal(pcss('a[rel="tag"] ~ a'), 'nofollow-anchor')
    expect_equal(pcss('ol#first-ol li:last-child'), 'seventh-li')
    expect_equal(pcss('ol#first-ol *:last-child'), c('li-div', 'seventh-li'))
    expect_equal(pcss('#outer-div:first-child'), 'outer-div')
    expect_equal(pcss('#outer-div :first-child'), c('name-anchor', 'first-li', 'li-div', 'p-b', 'checkbox-fieldset-disabled', 'area-href'))
    expect_equal(pcss('a[href]'), c('tag-anchor', 'nofollow-anchor'))
    expect_equal(pcss(':not(*)'), NULL)
    expect_equal(pcss('a:not([href])'), 'name-anchor')
    expect_equal(pcss('ol :Not(li[class])'), c('first-li', 'second-li', 'li-div', 'fifth-li', 'sixth-li', 'seventh-li'))
    expect_equal(pcss('a:not(:not([href]))', 'a[href]'), c('tag-anchor', 'nofollow-anchor'))
    expect_equal(pcss('li:is(:not([class]))'), c('first-li', 'second-li', 'fifth-li', 'sixth-li', 'seventh-li'))
    expect_equal(pcss('ol:has(:not(li))'), 'first-ol')

    expect_equal(pcss(':is(#first-li, #second-li)'), c('first-li', 'second-li'))
    expect_equal(pcss('a:is(#name-anchor, #tag-anchor)'), c('name-anchor', 'tag-anchor'))
    expect_equal(pcss(':is(.c)'), c('first-ol', 'third-li', 'fourth-li'))
    expect_equal(pcss(':matches(#first-li, #second-li)'), c('first-li', 'second-li'))
    expect_equal(pcss('a:matches(#name-anchor, #tag-anchor)'), c('name-anchor', 'tag-anchor'))
    expect_equal(pcss(':matches(.c)'), c('first-ol', 'third-li', 'fourth-li'))
    # :is()/:where() alternatives stay grouped: they AND with conditions
    # before and after the pseudo-class instead of OR-ing across the compound
    expect_equal(pcss('li.c:is(#third-li, #fifth-li)'), 'third-li')
    expect_equal(pcss('li.c:where(#third-li, #fifth-li)'), 'third-li')
    expect_equal(pcss(':is(li, ol):first-child'), 'first-li')
    expect_equal(pcss('li:is(.c):is(#fourth-li)'), 'fourth-li')
    # An always-true '*' argument makes the whole selector list match
    # everything; it must not be silently dropped
    expect_equal(pcss('li:is(#first-li, *)'), c('first-li', 'second-li', 'third-li', 'fourth-li', 'fifth-li', 'sixth-li', 'seventh-li'))
    expect_equal(pcss('li:not(#first-li, *)'), NULL)
    expect_equal(pcss('ol:nth-child(6 of a, *)'), 'second-ol')

    expect_equal(pcss('ol:has(li)'), 'first-ol')
    # :has(.c) matches all ancestors of elements with class 'c'
    expect_equal(pcss(':has(.c)'), c('html', 'nil', 'outer-div', 'first-ol'))

    # Invalid characters in XPath element names, should not crash
    expect_equal(pcss('di\ua0v', 'div\\['), NULL)
    expect_equal(pcss('[h\ua0ref]', '[h\\]ref]'), NULL)

    ## HTML-specific
    expect_equal(pcss(':link', html_only = TRUE), c('link-href', 'tag-anchor', 'nofollow-anchor', 'area-href'))
    expect_equal(pcss(':visited', html_only = TRUE), NULL)
    expect_equal(pcss(':enabled', html_only = TRUE), c('link-href', 'tag-anchor', 'nofollow-anchor', 'checkbox-unchecked', 'text-checked', 'checkbox-checked', 'area-href'))
    expect_equal(pcss(':disabled', html_only = TRUE), c('checkbox-disabled', 'checkbox-disabled-checked', 'fieldset', 'checkbox-fieldset-disabled'))
    expect_equal(pcss(':checked', html_only = TRUE), c('checkbox-checked', 'checkbox-disabled-checked'))
})

test_that("generic :lang() wildcard ranges match xml:lang", {
    skip_if_not_installed("xml2")
    library(xml2)

    doc <- read_xml(paste0(
        '<r>',
        '<p id="us" xml:lang="en-US">x</p>',
        '<p id="en" xml:lang="en">y</p>',
        '<p id="fr" xml:lang="fr">z</p>',
        '</r>'
    ))
    get_ids <- function(css) xml_attr(querySelectorAll(doc, css), "id")

    # en-* matches en-US and (per RFC 4647 extended filtering) plain en
    expect_equal(get_ids(":lang(en-*)"), c("us", "en"))
    expect_equal(get_ids(":lang(en)"), c("us", "en"))
    expect_equal(get_ids(":lang(en-US)"), "us")
    expect_equal(get_ids(":lang(fr-*)"), "fr")
})

test_that("of-type pseudo-classes work on element names needing quoting", {
    skip_if_not_installed("xml2")
    library(xml2)

    doc <- read_xml(paste0(
        '<r>',
        '<é id="e1"/>',
        '<b id="b1"/>',
        '<é id="e2"/>',
        '<ü id="u1"/>',
        '</r>'
    ))
    get_ids <- function(css) xml_attr(querySelectorAll(doc, css), "id")

    expect_equal(get_ids("é:first-of-type"), "e1")
    expect_equal(get_ids("é:last-of-type"), "e2")
    expect_equal(get_ids("é:nth-of-type(2)"), "e2")
    expect_equal(get_ids("é:only-of-type"), character(0))
    expect_equal(get_ids("ü:only-of-type"), "u1")
})

test_that("explicit no-namespace selectors exclude default-namespace elements", {
    skip_if_not_installed("xml2")
    library(xml2)

    doc <- read_xml(paste0(
        '<r>',
        '<é id="plain"/>',
        '<g xmlns="http://example.com/ns"><é id="defaulted"/></g>',
        '</r>'
    ))
    get_ids <- function(css) xml_attr(querySelectorAll(doc, css), "id")

    # no constraint written: a quoted name() test matches in any
    # namespace whose name carries no prefix
    expect_equal(get_ids("é"), c("plain", "defaulted"))
    # '|é' restricts the same test to the null namespace
    expect_equal(get_ids("|é"), "plain")

    # of-type sibling counts must keep the namespace restriction: a
    # same-named *sibling* in a default namespace is a different type
    doc <- read_xml(paste0(
        '<r>',
        '<é xmlns="http://example.com/ns" id="defaulted"/>',
        '<é id="first"/>',
        '<é id="last"/>',
        '<é xmlns="http://example.com/ns" id="defaulted2"/>',
        '</r>'
    ))
    get_ids <- function(css) xml_attr(querySelectorAll(doc, css), "id")

    expect_equal(get_ids("|é:first-of-type"), "first")
    expect_equal(get_ids("|é:last-of-type"), "last")
    expect_equal(get_ids("|é:nth-of-type(2)"), "last")

    # the only null-namespace é, despite the defaulted sibling
    doc <- read_xml(paste0(
        '<r>',
        '<é xmlns="http://example.com/ns" id="defaulted"/>',
        '<é id="plain"/>',
        '</r>'
    ))
    get_ids <- function(css) xml_attr(querySelectorAll(doc, css), "id")

    expect_equal(get_ids("|é:only-of-type"), "plain")
})

test_that("prefixed names in pseudo-class arguments resolve by namespace URI", {
    skip_if_not_installed("xml2")
    library(xml2)

    # the document binds the URI to prefix 's'; the query registers 'svg'
    doc <- read_xml(paste0(
        '<r xmlns:s="http://www.w3.org/2000/svg">',
        '<d id="hit"><s:g/></d>',
        '<d id="miss"><s:other/></d>',
        '</r>'
    ))
    ns <- c(svg = "http://www.w3.org/2000/svg")
    get_ids <- function(css) xml_attr(querySelectorAll(doc, css, ns = ns), "id")

    # top level and pseudo-class arguments agree on what 'svg|g' means
    expect_equal(length(querySelectorAll(doc, "svg|g", ns = ns)), 1L)
    expect_equal(length(querySelectorAll(doc, ":is(svg|g)", ns = ns)), 1L)
    expect_equal(get_ids("d:has(svg|g)"), "hit")
    expect_equal(get_ids("d:has(> svg|g)"), "hit")
    expect_equal(get_ids("d:not(:has(svg|g))"), "miss")
    expect_equal(get_ids("d:has(svg|*)"), c("hit", "miss"))
})

test_that(":only-child and :only-of-type match the root element", {
    skip_if_not_installed("xml2")
    library(xml2)

    doc <- read_xml("<root><a/></root>")
    count <- function(css)
        length(xml_find_all(doc, css_to_xpath(css)))

    # :only-child is defined as :first-child:last-child, which matches
    # the root element, so :only-child must match it too
    expect_equal(count("root:first-child:last-child"), 1)
    expect_equal(count("root:only-child"), 1)
    expect_equal(count("root:only-of-type"), 1)
    expect_equal(count("a:only-child"), 1)
    expect_equal(count("a:only-of-type"), 1)
})

test_that(":enabled and :disabled match inputs with no type attribute", {
    skip_if_not_installed("xml2")
    library(xml2)

    doc <- read_html(paste0(
        '<form>',
        '<input id="plain-disabled" disabled="" />',
        '<input id="plain-enabled" />',
        '<input type="hidden" id="hidden-disabled" disabled="" />',
        '<input type="hidden" id="hidden-plain" />',
        '</form>'
    ))
    get_ids <- function(css) {
        xpath <- css_to_xpath(css, translator = "html")
        unlist(lapply(xml_find_all(doc, xpath), xml_attr, "id"))
    }

    # An <input> with no type attribute defaults to type=text, so it
    # participates in :enabled/:disabled; type=hidden inputs never do
    expect_equal(get_ids("input:disabled"), "plain-disabled")
    expect_equal(get_ids("input:enabled"), "plain-enabled")
})
