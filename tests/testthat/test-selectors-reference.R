# Pins every example translation printed on ?selectors against a live
# css_to_xpath() call, so that page cannot drift from the translator.
# A row whose XPath is too long to print is checked here by the
# element/attribute facts the page states about it instead.

test_that("?selectors combinator examples match live translation", {
    expect_equal(css_to_xpath("e f"), "descendant-or-self::e//f")
    expect_equal(css_to_xpath("e > f"), "descendant-or-self::e/f")
    expect_equal(css_to_xpath("e + f"),
                 "descendant-or-self::e/following-sibling::*[1][self::f]")
    expect_equal(css_to_xpath("e ~ f"),
                 "descendant-or-self::e/following-sibling::f")
    expect_error(css_to_xpath("e || f"), class = "selectrs_error")
})

test_that("?selectors simple-selector examples match live translation", {
    expect_equal(css_to_xpath("*"), "descendant-or-self::*")
    expect_equal(css_to_xpath("e"), "descendant-or-self::e")
    expect_equal(css_to_xpath(".class"),
                 "descendant-or-self::*[contains(concat(' ', normalize-space(@class), ' '), ' class ')]")
    expect_equal(css_to_xpath("#id"), "descendant-or-self::*[@id = 'id']")
})

test_that("?selectors attribute-selector examples match live translation", {
    expect_equal(css_to_xpath("[attr]"), "descendant-or-self::*[@attr]")
    expect_equal(css_to_xpath("[attr=val]"),
                 "descendant-or-self::*[@attr = 'val']")
    expect_equal(css_to_xpath("[attr~=val]"),
                 "descendant-or-self::*[contains(concat(' ', normalize-space(@attr), ' '), ' val ')]")
    expect_equal(css_to_xpath("[attr|=val]"),
                 "descendant-or-self::*[@attr = 'val' or starts-with(@attr, 'val-')]")
    expect_equal(css_to_xpath("[attr^=val]"),
                 "descendant-or-self::*[starts-with(@attr, 'val')]")
    expect_equal(css_to_xpath("[attr$=val]"),
                 "descendant-or-self::*[substring(@attr, string-length(@attr)-2) = 'val']")
    expect_equal(css_to_xpath("[attr*=val]"),
                 "descendant-or-self::*[contains(@attr, 'val')]")
    expect_equal(css_to_xpath("[attr=val i]"),
                 "descendant-or-self::*[translate(@attr, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz') = 'val']")
    expect_equal(css_to_xpath("[attr=val s]"),
                 "descendant-or-self::*[@attr = 'val']")
    expect_error(css_to_xpath("[attr=val x]"), class = "selectrs_error")
})

test_that("?selectors structural pseudo-class examples match live translation", {
    expect_equal(css_to_xpath(":root"),
                 "descendant-or-self::*[not(parent::*)]")
    expect_equal(css_to_xpath(":first-child"),
                 "descendant-or-self::*[count(preceding-sibling::*) = 0]")
    expect_equal(css_to_xpath(":last-child"),
                 "descendant-or-self::*[count(following-sibling::*) = 0]")
    expect_equal(css_to_xpath(":only-child"),
                 "descendant-or-self::*[count(preceding-sibling::*) = 0 and count(following-sibling::*) = 0]")
    expect_equal(css_to_xpath("e:first-of-type"),
                 "descendant-or-self::e[count(preceding-sibling::e) = 0]")
    expect_equal(css_to_xpath("e:last-of-type"),
                 "descendant-or-self::e[count(following-sibling::e) = 0]")
    expect_equal(css_to_xpath("e:only-of-type"),
                 "descendant-or-self::e[count(preceding-sibling::e) = 0 and count(following-sibling::e) = 0]")
    expect_error(css_to_xpath("*:first-of-type"), class = "selectrs_error")
    expect_equal(css_to_xpath(":nth-child(2n+1)"),
                 "descendant-or-self::*[count(preceding-sibling::*) mod 2 = 0]")
    # A B outside the first cycle adds the bound and the offset the page
    # describes.
    expect_equal(css_to_xpath(":nth-child(3n+2)"),
                 "descendant-or-self::*[count(preceding-sibling::*) >= 1 and (count(preceding-sibling::*) + 2) mod 3 = 0]")
    expect_equal(css_to_xpath(":nth-child(2n+1 of .a)"),
                 "descendant-or-self::*[count(preceding-sibling::*[contains(concat(' ', normalize-space(@class), ' '), ' a ')]) mod 2 = 0 and contains(concat(' ', normalize-space(@class), ' '), ' a ')]")
    expect_equal(css_to_xpath(":nth-last-child(2)"),
                 "descendant-or-self::*[count(following-sibling::*) = 1]")
    expect_equal(css_to_xpath("e:nth-of-type(2)"),
                 "descendant-or-self::e[count(preceding-sibling::e) = 1]")
    expect_equal(css_to_xpath("e:nth-last-of-type(2)"),
                 "descendant-or-self::e[count(following-sibling::e) = 1]")
    expect_equal(css_to_xpath(":empty"),
                 "descendant-or-self::*[not(*) and not(string-length())]")
    expect_equal(css_to_xpath(":scope"), "self::*")
})

test_that("?selectors selector-list pseudo-class examples match live translation", {
    expect_equal(css_to_xpath(":not(e)"),
                 "descendant-or-self::*[not(self::e)]")
    expect_equal(css_to_xpath(":is(e, f)"),
                 "descendant-or-self::*[self::e or self::f]")
    expect_equal(css_to_xpath(":matches(e, f)"),
                 "descendant-or-self::*[self::e or self::f]")
    expect_equal(css_to_xpath(":where(e, f)"),
                 "descendant-or-self::*[self::e or self::f]")
    expect_equal(css_to_xpath(":has(> e)"),
                 "descendant-or-self::*[child::e]")
    expect_error(css_to_xpath(":is(:scope)"), class = "selectrs_error")
    expect_error(css_to_xpath("a:has(:has(b))"), class = "selectrs_error")
})

test_that("?selectors linguistic/directionality examples match live translation", {
    expect_equal(css_to_xpath(":lang(en)"), "descendant-or-self::*[lang('en')]")
    # A trailing wildcard is the same test as the bare subtag; a whole-range
    # wildcard asks only that a language is tagged at all.
    expect_equal(css_to_xpath(":lang(en-*)"), css_to_xpath(":lang(en)"))
    expect_equal(css_to_xpath(":lang(*)"),
                 "descendant-or-self::*[ancestor-or-self::*[@xml:lang][1][string-length(@xml:lang) > 0]]")
    for (tr in c("generic", "html", "xhtml"))
        expect_error(css_to_xpath(":lang(*-CH)", translator = tr),
                     class = "selectrs_error")
    expect_equal(css_to_xpath(":dir(ltr)"), "descendant-or-self::*[0]")

    # generic prefix-matches; html/xhtml may skip subtags.
    expect_equal(css_to_xpath(":lang(de-DE)"),
                 "descendant-or-self::*[lang('de-DE')]")
    expect_true(grepl("'-de-'", css_to_xpath(":lang(de-DE)", translator = "html"),
                      fixed = TRUE))
    # The html translator reads lang, the xhtml one xml:lang in preference.
    expect_false(grepl("@xml:lang", css_to_xpath(":lang(en)", translator = "html"),
                       fixed = TRUE))
    expect_true(grepl("@xml:lang", css_to_xpath(":lang(en)", translator = "xhtml"),
                      fixed = TRUE))
})

test_that("?selectors link/interaction-state examples match live translation", {
    never <- "descendant-or-self::*[0]"
    for (pseudo in c(":link", ":any-link", ":visited", ":hover", ":active",
                     ":focus", ":focus-within", ":focus-visible", ":target",
                     ":target-within", ":local-link"))
        expect_equal(css_to_xpath(pseudo), never)

    expect_equal(css_to_xpath(":visited", translator = "html"), never)
    for (pseudo in c(":hover", ":active", ":focus", ":focus-within",
                     ":focus-visible", ":target", ":target-within",
                     ":local-link"))
        expect_equal(css_to_xpath(pseudo, translator = "html"), never)

    # html/xhtml: a and area elements carrying an href, and nothing else.
    link <- css_to_xpath(":link", translator = "html")
    expect_equal(css_to_xpath(":any-link", translator = "html"), link)
    expect_true(grepl("@href", link, fixed = TRUE))
    expect_true(grepl("local-name() = 'a'", link, fixed = TRUE))
    expect_true(grepl("local-name() = 'area'", link, fixed = TRUE))
    expect_equal(css_to_xpath("link:link", prefix = "", translator = "html"),
                 "link[0]")
})

test_that("?selectors HTML form-state pseudo-classes match the documented element set", {
    # The full XPath for these is too long to print on the page; assert the
    # documented element/attribute facts against the live translator instead.
    html <- function(css) css_to_xpath(css, translator = "html")

    checked <- html(":checked")
    expect_true(grepl("'option'", checked, fixed = TRUE))
    expect_true(grepl("@selected", checked, fixed = TRUE))
    expect_true(grepl("@checked", checked, fixed = TRUE))
    expect_true(grepl("'checkbox'", checked, fixed = TRUE))
    expect_true(grepl("'radio'", checked, fixed = TRUE))

    for (element in c("button", "input", "select", "textarea", "optgroup",
                      "option", "fieldset")) {
        expect_true(grepl(paste0("'", element, "'"), html(":enabled"), fixed = TRUE))
        expect_true(grepl(paste0("'", element, "'"), html(":disabled"), fixed = TRUE))
    }
    expect_true(grepl("'legend'", html(":disabled"), fixed = TRUE))

    # :required and :optional cover the same element set, differing only in
    # whether @required is present.
    required <- html(":required")
    optional <- html(":optional")
    expect_true(grepl("@required and ", required, fixed = TRUE))
    expect_true(grepl("not(@required) and ", optional, fixed = TRUE))
    for (type in c("hidden", "range", "color", "submit", "image", "reset",
                   "button"))
        expect_true(grepl(paste0("|", type, "|"), required, fixed = TRUE))

    # :read-only is exactly the negation of :read-write.
    readWrite <- html(":read-write")
    readWriteInner <- sub("\\]$", "",
                          sub("^descendant-or-self::\\*\\[", "", readWrite))
    expect_equal(html(":read-only"),
                 paste0("descendant-or-self::*[not(", readWriteInner, ")]"))
    expect_true(grepl("@contenteditable", readWrite, fixed = TRUE))

    expect_true(grepl("@placeholder", html(":placeholder-shown"), fixed = TRUE))
    # :default adds the first submit button of the nearest ancestor form to
    # what :checked matches.
    expect_true(grepl("'form'", html(":default"), fixed = TRUE))
    expect_true(grepl("'submit'", html(":default"), fixed = TRUE))
})

test_that("?selectors namespace examples match live translation", {
    expect_equal(css_to_xpath("p"), "descendant-or-self::p")
    expect_equal(css_to_xpath("d|p"), "descendant-or-self::d:p")
    expect_equal(css_to_xpath("*|p"),
                 "descendant-or-self::*[local-name() = 'p']")
    expect_equal(css_to_xpath("|p"), "descendant-or-self::p")
    # The html translator lower-cases namespaced names too.
    expect_equal(css_to_xpath("svg|linearGradient", translator = "html"),
                 "descendant-or-self::svg:lineargradient")
    expect_equal(css_to_xpath("svg|linearGradient", translator = "xhtml"),
                 "descendant-or-self::svg:linearGradient")
})

test_that("?selectors rejected constructs are errors", {
    for (selector in c("::before", "::slotted(a)", "::part(x)", ":contains(x)",
                       "[attr!=val]", ":nth-col(2)", ":nth-last-col(2)",
                       ":host", "&", ":valid", ":in-range", ":indeterminate"))
        expect_error(css_to_xpath(selector), class = "selectrs_error")
})
