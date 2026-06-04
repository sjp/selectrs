test_that("Generic translator validates language arguments", {
    css <- function(x) css_to_xpath(x, translator = "generic")
    expect_equal(css("xml:lang(en)"), "descendant-or-self::xml[(lang('en'))]")
    expect_equal(css("xml:lang(en-nz)"), "descendant-or-self::xml[(lang('en-nz'))]")

    expect_error(css("xml:lang()"),
                 'Unable to parse the CSS selector "xml:lang()"', fixed = TRUE)
    expect_error(css("xml:lang(1)"),
                 'Unable to parse the CSS selector "xml:lang(1)"', fixed = TRUE)

    # Multiple languages with OR logic
    expect_equal(css("xml:lang(en, fr)"), "descendant-or-self::xml[((lang('en') or lang('fr')))]")
    expect_equal(css("xml:lang(en, de, fr)"), "descendant-or-self::xml[((lang('en') or lang('de') or lang('fr')))]")
})

test_that("HTML translator validates language arguments", {
    css <- function(x) css_to_xpath(x, translator = "html")
    expect_equal(css("html:lang(en)"), "descendant-or-self::html[(ancestor-or-self::*[@lang][1][starts-with(concat(translate(@lang, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '-'), 'en-')])]")
    expect_equal(css("html:lang(en-nz)"), "descendant-or-self::html[(ancestor-or-self::*[@lang][1][starts-with(concat(translate(@lang, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '-'), 'en-nz-')])]")

    expect_error(css("html:lang()"),
                 'Unable to parse the CSS selector "html:lang()"', fixed = TRUE)
    expect_error(css("html:lang(1)"),
                 'Unable to parse the CSS selector "html:lang(1)"', fixed = TRUE)

    # Multiple languages with OR logic
    expect_equal(css("html:lang(en, fr)"),
                 "descendant-or-self::html[((ancestor-or-self::*[@lang][1][starts-with(concat(translate(@lang, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '-'), 'en-')] or ancestor-or-self::*[@lang][1][starts-with(concat(translate(@lang, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '-'), 'fr-')]))]")
})

test_that("HTML translator lowercases attribute names but not values", {
    css <- function(x) css_to_xpath(x, translator = "html")

    # Attribute names in HTML are case-insensitive, but values are not
    expect_equal(css('[Data-State="Active"]'),
                 "descendant-or-self::*[(@data-state = 'Active')]")
    expect_equal(css('[data-state~="Active"]'),
                 paste0("descendant-or-self::*[(@data-state and ",
                        "contains(concat(' ', ",
                        "normalize-space(@data-state), ' '), ",
                        "' Active '))]"))
    # Element names are still lowercased
    expect_equal(css('DIV[data-state="Active"]'),
                 "descendant-or-self::div[(@data-state = 'Active')]")
})

test_that("Generic translator handles :lang() wildcards and comma lists", {
    css <- function(x) css_to_xpath(x, translator = "generic")

    # Simple languages still work
    expect_equal(css("div:lang(en)"), "descendant-or-self::div[(lang('en'))]")

    # Wildcard * matches everything
    expect_equal(css('div:lang(*)'), "descendant-or-self::div[(true())]")

    # Wildcard suffix like en-* for prefix matching, which XPath's lang()
    # already does natively
    expect_equal(css('div:lang(en-*)'), "descendant-or-self::div[(lang('en'))]")
    expect_equal(css('div:lang(fr-*)'), "descendant-or-self::div[(lang('fr'))]")

    # Comma-separated lists with OR logic
    expect_equal(css('div:lang(en, fr)'), "descendant-or-self::div[((lang('en') or lang('fr')))]")
    expect_equal(css('div:lang(en, de, fr)'), "descendant-or-self::div[((lang('en') or lang('de') or lang('fr')))]")

    # Mixed wildcards and regular languages
    expect_equal(css('div:lang(en-*, fr)'), "descendant-or-self::div[((lang('en') or lang('fr')))]")
    expect_equal(css('div:lang(*, de)'), "descendant-or-self::div[((true() or lang('de')))]")
})

test_that("HTML translator handles :lang() wildcards and comma lists", {
    css <- function(x) css_to_xpath(x, translator = "html")

    # Wildcard * matches any element with lang attribute
    expect_equal(css('div:lang(*)'), "descendant-or-self::div[(ancestor-or-self::*[@lang])]")

    # Wildcard suffix for prefix matching
    expect_equal(css('div:lang(en-*)'),
                 "descendant-or-self::div[(ancestor-or-self::*[@lang][1][starts-with(concat(translate(@lang, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '-'), 'en-')])]")

    # Multiple values with OR logic
    expect_equal(css('div:lang(en, fr)'),
                 "descendant-or-self::div[((ancestor-or-self::*[@lang][1][starts-with(concat(translate(@lang, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '-'), 'en-')] or ancestor-or-self::*[@lang][1][starts-with(concat(translate(@lang, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '-'), 'fr-')]))]")
})

test_that("Generic translator handles :dir() function", {
    css <- function(x) css_to_xpath(x, translator = "generic")

    # :dir() uses "never matches" pattern (requires runtime directionality detection)
    expect_equal(css("div:dir(ltr)"), "descendant-or-self::div[(0)]")
    expect_equal(css("div:dir(rtl)"), "descendant-or-self::div[(0)]")
    expect_equal(css(":dir(ltr)"), "descendant-or-self::*[(0)]")

    expect_error(css("div:dir()"),
                 'Unable to parse the CSS selector "div:dir()"', fixed = TRUE)
    expect_error(css("div:dir(1)"),
                 'Unable to parse the CSS selector "div:dir(1)"', fixed = TRUE)
    # exactly one identifier: none of :lang()'s strings, wildcards, or lists
    expect_error(css("div:dir(ltr rtl)"),
                 'Unable to parse the CSS selector "div:dir(ltr rtl)"', fixed = TRUE)
    expect_error(css("div:dir(ltr, rtl)"),
                 'Unable to parse the CSS selector "div:dir(ltr, rtl)"', fixed = TRUE)
    expect_error(css('div:dir("ltr")'),
                 'Unable to parse the CSS selector "div:dir(\\"ltr\\")"', fixed = TRUE)
    expect_error(css("div:dir(*)"),
                 'Unable to parse the CSS selector "div:dir(*)"', fixed = TRUE)
})

test_that("HTML translator handles :dir() function", {
    css <- function(x) css_to_xpath(x, translator = "html")

    # :dir() uses "never matches" pattern (requires runtime directionality detection)
    expect_equal(css("div:dir(ltr)"), "descendant-or-self::div[(0)]")
    expect_equal(css("div:dir(rtl)"), "descendant-or-self::div[(0)]")
    expect_equal(css(":dir(ltr)"), "descendant-or-self::*[(0)]")

    expect_error(css("div:dir()"),
                 'Unable to parse the CSS selector "div:dir()"', fixed = TRUE)
    expect_error(css("div:dir(1)"),
                 'Unable to parse the CSS selector "div:dir(1)"', fixed = TRUE)
})

test_that(":lang() and :dir() reject a lone '-' argument", {
    # A lone '-' is not a valid <ident> per css-syntax (an ident may
    # start with '-' only when followed by an ident-start code point
    # or a second '-')
    for (translator in c("generic", "html")) {
        css <- function(x) css_to_xpath(x, translator = translator)
        expect_error(css("e:lang(-)"),
                     'Unable to parse the CSS selector "e:lang(-)"', fixed = TRUE)
        expect_error(css("e:dir(-)"),
                     'Unable to parse the CSS selector "e:dir(-)"', fixed = TRUE)
        expect_error(css("e:lang(en, -)"),
                     'Unable to parse the CSS selector "e:lang(en, -)"', fixed = TRUE)
        # valid idents starting or ending with '-' keep working
        expect_no_error(css("e:lang(--x)"))
        expect_no_error(css("e:lang(en--)"))
        expect_no_error(css("e:lang(en-*)"))
    }
})

test_that("unimplemented methods throw errors", {
    css <- function(x) css_to_xpath(x, translator = "generic")

    expect_error(css("*:nth-of-type(2n)"), "on the universal selector")
    expect_error(css("*:nth-last-of-type(2n)"), "on the universal selector")
    expect_error(css("*:first-of-type"), "on the universal selector")
    expect_error(css("*:last-of-type"), "on the universal selector")
    expect_error(css("*:only-of-type"), "on the universal selector")
})
