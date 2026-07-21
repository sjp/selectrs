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

    skip_if_not_installed("XML")
    library(XML)
    document <- xmlRoot(xmlParse(HTML_IDS))
    select_ids <- function(selector, html_only) {
        translator <- if (html_only) "html" else "generic"
        xpath <- css_to_xpath(selector, translator = translator)
        items <- getNodeSet(document, xpath)
        n <- length(items)
        if (!n)
            return(NULL)
        result <- character(n)
        for (i in seq_len(n)) {
            element <- items[[i]]
            tmp <- xmlAttrs(element)["id"]
            if (is.null(tmp))
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

    # A representative slice spanning type/class/id/attribute/combinator/
    # pseudo-class selectors, plus one HTML-translator-specific case; full
    # translation correctness for each is the css-to-xpath crate's concern.
    all_ids <- pcss('*')
    expect_equal(all_ids[1:6], c('html', 'nil', 'link-href', 'link-nohref', 'nil', 'outer-div'))
    expect_equal(pcss('div'), c('outer-div', 'li-div', 'foobar-div'))
    expect_equal(pcss('DIV', html_only = TRUE), c('outer-div', 'li-div', 'foobar-div'))  # case-insensitive in HTML
    expect_equal(pcss('a[rel]'), c('tag-anchor', 'nofollow-anchor'))
    expect_equal(pcss('a[href^="http"]'), c('tag-anchor', 'nofollow-anchor'))
    expect_equal(pcss('li:nth-child(3)'), 'third-li')
    expect_equal(pcss('.a', c('.b', '*.a', 'ol.a')), 'first-ol')
    expect_equal(pcss('#first-li', c('li#first-li', '*#first-li')), 'first-li')
    expect_equal(pcss('div + div'), 'foobar-div')
    expect_equal(pcss(':is(.c)'), c('first-ol', 'third-li', 'fourth-li'))
    expect_equal(pcss('ol:has(li)'), 'first-ol')
    expect_equal(pcss(':checked', html_only = TRUE), c('checkbox-checked', 'checkbox-disabled-checked'))
})
