# Data borrowed from http://mootools.net/slickspeed/: a representative slice
# spanning type/class/id/attribute/combinator/pseudo-class selectors at
# scale, against the XHTML document in shakespeare.html. Full translation
# correctness is the css-to-xpath crate's concern.

forEachBackend("selection works correctly on a shakespearean document", function(backend) {
    document <- backend$parseHtml(shakespeareHtml())
    body <- backend$findFirst(document, "//body")

    count <- function(selector) {
        length(backend$findAll(body, css_to_xpath(selector)))
    }

    expect_equal(count('*'), 246)
    expect_equal(count('div:nth-child(odd)'), 137)
    expect_equal(count('div:first-child'), 51)
    expect_equal(count('div > div'), 242)
    expect_equal(count('div + div'), 190)
    expect_equal(count('.dialog'), 51)
    expect_equal(count('div.character, div.dialog'), 99)
    expect_equal(count('#speech5'), 1)
    expect_equal(count('div[class]'), 103)
    expect_equal(count('div[class^=dia]'), 51)
})
