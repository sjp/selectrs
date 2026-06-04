# Ported from selectr's tests/testthat/test-xmllang-XML.R (sjp/selectr@9ed9bb2, by
# Simon Potter), adapted for selectrs: testthat edition-3 idioms
# (expect_equal instead of expect_that/equals, no context()), with the XML suite
# guarded by skip_if_not_installed()
# and the internal R6 translator replaced by css_to_xpath().

test_that("xml lang function matches correct elements", {
    xmlLangText <- paste0('<test>',
                          '<a id="first" xml:lang="en">a</a>',
                          '<b id="second" xml:lang="en-US">b</b>',
                          '<c id="third" xml:lang="en-Nz">c</c>',
                          '<d id="fourth" xml:lang="En-us">d</d>',
                          '<e id="fifth" xml:lang="fr">e</e>',
                          '<f id="sixth" xml:lang="ru">f</f>',
                          '<g id="seventh" xml:lang="de"><h id="eighth" xml:lang="zh" /></g>',
                          '</test>')

    skip_if_not_installed("XML")
    library(XML)
    xmldoc <- xmlRoot(xmlParse(xmlLangText))

    pid <- function(selector) {
        xpath <- css_to_xpath(selector)
        items <- getNodeSet(xmldoc, xpath)
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

    expect_equal(pid(':lang("EN")'), c('first', 'second', 'third', 'fourth'))
    expect_equal(pid(':lang("en-us")'), c('second', 'fourth'))
    expect_equal(pid(':lang(en-nz)'), 'third')
    expect_equal(pid(':lang(fr)'), 'fifth')
    expect_equal(pid(':lang(ru)'), 'sixth')
    expect_equal(pid(":lang('ZH')"), 'eighth')
    expect_equal(pid(':lang(de) :lang(zh)'), 'eighth')
    expect_equal(pid(':lang(en), :lang(zh)'), c('first', 'second', 'third', 'fourth', 'eighth'))
    expect_equal(pid(":lang(es)"), NULL)
})
