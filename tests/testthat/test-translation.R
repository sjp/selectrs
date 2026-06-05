xpath <- function(css) {
    css_to_xpath(css, prefix = "")
}

test_that("translation of simple selectors to XPath works", {
    expect_equal(xpath("*"), "*")
    expect_equal(xpath("e"), "e")
    expect_equal(xpath("*|e"), "*[local-name() = 'e']")
    expect_equal(xpath("|e"), "e")
    expect_equal(xpath("|*"), "*[namespace-uri() = '']")
    # a name needing quoting keeps the no-namespace constraint
    expect_equal(xpath("|é"), "*[name() = 'é' and namespace-uri() = '']")
    expect_equal(xpath("*|*"), "*")
    expect_equal(xpath("e|f"), "e:f")
    expect_equal(xpath("svg|*"), "svg:*")
    expect_equal(xpath("e[foo]"), "e[@foo]")
    expect_equal(xpath("e[foo|bar]"), "e[@foo:bar]")
    expect_equal(xpath("[*|foo]"), "*[@*[local-name() = 'foo']]")
    expect_equal(xpath("[|foo]"), "*[@foo]")
    expect_equal(xpath('e[foo="bar"]'), "e[@foo = 'bar']")
    expect_equal(xpath('e[foo=""]'), "e[@foo = '']")
    expect_equal(xpath('e[foo|=""]'),
                 "e[@foo and (@foo = '' or starts-with(@foo, '-'))]")
    expect_equal(xpath("e[foo='(test)']"), "e[@foo = '(test)']")
    expect_equal(xpath('e[foo="(test)"]'), "e[@foo = '(test)']")
    expect_equal(xpath("e[foo='(abc)']"), "e[@foo = '(abc)']")
    expect_equal(xpath("e[foo='(e2e)']"), "e[@foo = '(e2e)']")
    expect_equal(xpath('e[foo="(e2e)"]'), "e[@foo = '(e2e)']")
    expect_equal(xpath("e[foo='(123)']"), "e[@foo = '(123)']")
    expect_equal(xpath("e[foo='(12345)']"), "e[@foo = '(12345)']")
    # Six hex digits (max for CSS unicode escape)
    expect_equal(xpath("e[foo='(abcdef)']"), "e[@foo = '(abcdef)']")
    expect_equal(xpath("e[foo='(123456)']"), "e[@foo = '(123456)']")
    # Seven hex digits (exceeds max, so not unicode escape required)
    expect_equal(xpath("e[foo='(1234567)']"), "e[@foo = '(1234567)']")
    expect_equal(xpath("e[foo='(AbCdEf)']"), "e[@foo = '(AbCdEf)']")
    expect_equal(xpath("e[foo='(E2E)']"), "e[@foo = '(E2E)']")
    expect_equal(xpath("e[foo='(o2o)']"), "e[@foo = '(o2o)']")
    expect_equal(xpath('e[foo="(o2o)"]'), "e[@foo = '(o2o)']")
    expect_equal(xpath("e[foo='(xyz)']"), "e[@foo = '(xyz)']")
    expect_equal(xpath("e[foo='(test123)']"), "e[@foo = '(test123)']")
    expect_equal(xpath("e[foo='(abc)(def)']"), "e[@foo = '(abc)(def)']")
    expect_equal(xpath("e[foo='(abc )']"), "e[@foo = '(abc )']")
    expect_equal(xpath('e[foo~="bar"]'),
                 "e[@foo and contains(concat(' ', normalize-space(@foo), ' '), ' bar ')]")
    expect_equal(xpath('e[foo^="bar"]'),
                 "e[@foo and starts-with(@foo, 'bar')]")
    expect_equal(xpath('e[foo$="bar"]'),
                 "e[@foo and substring(@foo, string-length(@foo)-2) = 'bar']")
    expect_equal(xpath('e[foo*="bar"]'),
                 "e[@foo and contains(@foo, 'bar')]")
    expect_equal(xpath('e[hreflang|="en"]'),
                 "e[@hreflang and (@hreflang = 'en' or starts-with(@hreflang, 'en-'))]")
    # CSS Selectors Level 4 case-sensitivity flags
    lower_foo <- paste0("translate(@foo, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',",
                        " 'abcdefghijklmnopqrstuvwxyz')")
    expect_equal(xpath('e[foo="Bar" i]'),
                 paste0("e[", lower_foo, " = 'bar']"))
    expect_equal(xpath('e[foo^="Bar" i]'),
                 paste0("e[", lower_foo, " and starts-with(",
                        lower_foo, ", 'bar')]"))
    expect_equal(xpath('e[foo$="Bar" i]'),
                 paste0("e[", lower_foo, " and substring(",
                        lower_foo, ", string-length(",
                        lower_foo, ")-2) = 'bar']"))
    expect_equal(xpath('e[foo*="Bar" i]'),
                 paste0("e[", lower_foo, " and contains(",
                        lower_foo, ", 'bar')]"))
    expect_equal(xpath('e[foo~="Bar" i]'),
                 paste0("e[", lower_foo,
                        " and contains(concat(' ', normalize-space(",
                        lower_foo, "), ' '), ' bar ')]"))
    expect_equal(xpath('e[foo|="Bar" i]'),
                 paste0("e[", lower_foo, " and (",
                        lower_foo, " = 'bar' or starts-with(",
                        lower_foo, ", 'bar-'))]"))
    # The 'i' flag is ASCII case-insensitive: non-ASCII characters such
    # as 'É' are left alone
    expect_equal(xpath("e[foo='\\C9 x' i]"),
                 paste0("e[", lower_foo, " = '\uC9x']"))
    # An empty value cannot differ by case, so it keeps the exact
    # (existence-preserving) translation
    expect_equal(xpath('e[foo="" i]'), "e[@foo = '']")
    # The 's' flag requests the default case-sensitive matching
    expect_equal(xpath('e[foo="Bar" s]'), "e[@foo = 'Bar']")
    expect_equal(xpath('e[foo^="Bar" s]'),
                 "e[@foo and starts-with(@foo, 'Bar')]")
    expect_equal(xpath('e.warning'),
                 "e[@class and contains(concat(' ', normalize-space(@class), ' '), ' warning ')]")
    expect_equal(xpath('e#myid'),
                 "e[@id = 'myid']")
    expect_equal(xpath('e f'),
                 "e//f")
    expect_equal(xpath('e > f'),
                 "e/f")
    expect_equal(xpath('e + f'),
                 "e/following-sibling::*[1][self::f]")
    expect_equal(xpath('e ~ f'),
                 "e/following-sibling::f")
    expect_equal(xpath('div#container p'),
                 "div[@id = 'container']//p")
})

test_that("translation of pseudo-classes to XPath works", {
    expect_equal(xpath('e:nth-child(1)'),
                 "e[count(preceding-sibling::*) = 0]")
    expect_equal(xpath('e:nth-child(3n+2)'),
                 "e[count(preceding-sibling::*) >= 1 and (count(preceding-sibling::*) +2) mod 3 = 0]")
    expect_equal(xpath('e:nth-child(3n-2)'),
                 "e[count(preceding-sibling::*) mod 3 = 0]")
    expect_equal(xpath('e:nth-child(-n+6)'),
                 "e[count(preceding-sibling::*) <= 5]")
    expect_equal(xpath('e:nth-child(n)'), "e")
    expect_equal(xpath('e:nth-last-child(1)'),
                 "e[count(following-sibling::*) = 0]")
    expect_equal(xpath('e:nth-last-child(2n)'),
                 "e[(count(following-sibling::*) +1) mod 2 = 0]")
    expect_equal(xpath('e:nth-last-child(2n+1)'),
                 "e[count(following-sibling::*) mod 2 = 0]")
    expect_equal(xpath('e:nth-last-child(2n+2)'),
                 "e[count(following-sibling::*) >= 1 and (count(following-sibling::*) +1) mod 2 = 0]")
    expect_equal(xpath('e:nth-last-child(3n+1)'),
                 "e[count(following-sibling::*) mod 3 = 0]")
    expect_equal(xpath('e:nth-last-child(-n+2)'),
                 "e[count(following-sibling::*) <= 1]")
    expect_equal(xpath('e:nth-of-type(1)'),
                 "e[count(preceding-sibling::e) = 0]")
    expect_equal(xpath('e:nth-last-of-type(1)'),
                 "e[count(following-sibling::e) = 0]")
    expect_equal(xpath('div e:nth-last-of-type(1) .aclass'),
                 "div//e[count(following-sibling::e) = 0]//*[@class and contains(concat(' ', normalize-space(@class), ' '), ' aclass ')]")
    expect_equal(xpath('e:first-child'),
                 "e[count(preceding-sibling::*) = 0]")
    expect_equal(xpath('e:last-child'),
                 "e[count(following-sibling::*) = 0]")
    expect_equal(xpath('e:first-of-type'),
                 "e[count(preceding-sibling::e) = 0]")
    expect_equal(xpath('e:last-of-type'),
                 "e[count(following-sibling::e) = 0]")
    expect_equal(xpath('e:only-child'),
                 "e[count(preceding-sibling::*) = 0 and count(following-sibling::*) = 0]")
    expect_equal(xpath('e:only-of-type'),
                 "e[count(preceding-sibling::e) = 0 and count(following-sibling::e) = 0]")
    # element names needing quoting fold into a name() condition; the
    # of-type pseudos count same-type siblings through the same test
    expect_equal(xpath('é:first-of-type'),
                 "*[name() = 'é' and count(preceding-sibling::*[name() = 'é']) = 0]")
    expect_equal(xpath('é:nth-of-type(2)'),
                 "*[name() = 'é' and count(preceding-sibling::*[name() = 'é']) = 1]")
    expect_equal(xpath('é:only-of-type'),
                 "*[name() = 'é' and count(preceding-sibling::*[name() = 'é']) = 0 and count(following-sibling::*[name() = 'é']) = 0]")
    # '*|e' supports the of-type pseudos via local-name()
    expect_equal(xpath('*|e:first-of-type'),
                 "*[local-name() = 'e' and count(preceding-sibling::*[local-name() = 'e']) = 0]")
    expect_equal(xpath('*|e:nth-of-type(2)'),
                 "*[local-name() = 'e' and count(preceding-sibling::*[local-name() = 'e']) = 1]")
    expect_equal(xpath('*|e:only-of-type'),
                 "*[local-name() = 'e' and count(preceding-sibling::*[local-name() = 'e']) = 0 and count(following-sibling::*[local-name() = 'e']) = 0]")
    # '|é' pins the null namespace, and the sibling counts must keep that
    # pin: a same-named sibling in a default namespace is a different type
    expect_equal(xpath('|é:first-of-type'),
                 "*[name() = 'é' and namespace-uri() = '' and count(preceding-sibling::*[name() = 'é' and namespace-uri() = '']) = 0]")
    expect_equal(xpath('|é:nth-of-type(2)'),
                 "*[name() = 'é' and namespace-uri() = '' and count(preceding-sibling::*[name() = 'é' and namespace-uri() = '']) = 1]")
    expect_equal(xpath('|é:only-of-type'),
                 "*[name() = 'é' and namespace-uri() = '' and count(preceding-sibling::*[name() = 'é' and namespace-uri() = '']) = 0 and count(following-sibling::*[name() = 'é' and namespace-uri() = '']) = 0]")
    expect_equal(xpath('e:empty'),
                 "e[not(*) and not(string-length())]")
    expect_equal(xpath('e:EmPTY'),
                 "e[not(*) and not(string-length())]")
    expect_equal(xpath('e:root'),
                 "e[not(parent::*)]")
    expect_equal(xpath('e:hover'),
                 "e[0]") # never matches
    expect_equal(xpath('e:not(:nth-child(odd))'),
                 "e[not(count(preceding-sibling::*) mod 2 = 0)]")
    expect_equal(xpath('e:nOT(*)'),
                 "e[0]") # never matches
    expect_equal(xpath('div:not(a, *)'),
                 "div[0]") # universal argument: never matches
    expect_equal(xpath('e ~ f:nth-child(3)'),
                 "e/following-sibling::f[count(preceding-sibling::*) = 2]")
    # An+B is ASCII case-insensitive per css-syntax
    expect_equal(xpath('e:nth-child(2N)'), xpath('e:nth-child(2n)'))
    expect_equal(xpath('e:nth-child(ODD)'), xpath('e:nth-child(odd)'))
    expect_equal(xpath('e:nth-child(EVEN)'), xpath('e:nth-child(even)'))
    expect_equal(xpath('e:nth-child(eVen)'), xpath('e:nth-child(even)'))
    expect_equal(xpath('e:nth-child(N+1)'), xpath('e:nth-child(n+1)'))
    expect_equal(xpath('e:nth-child(-N+3)'), xpath('e:nth-child(-n+3)'))
    expect_equal(xpath('e:nth-last-of-type(2N)'), xpath('e:nth-last-of-type(2n)'))

    # expect that the following do nothing for the generic translator
    expect_equal(xpath('a:any-link'), "a[0]")
    expect_equal(xpath('a:link'), "a[0]")
    expect_equal(xpath('a:visited'), "a[0]")
    expect_equal(xpath('a:hover'), "a[0]")
    expect_equal(xpath('a:active'), "a[0]")
    expect_equal(xpath('a:focus'), "a[0]")
    expect_equal(xpath('a:focus-within'), "a[0]")
    expect_equal(xpath('a:focus-visible'), "a[0]")
    expect_equal(xpath('a:target'), "a[0]")
    expect_equal(xpath('a:target-within'), "a[0]")
    expect_equal(xpath('a:local-link'), "a[0]")
    expect_equal(xpath('a:enabled'), "a[0]")
    expect_equal(xpath('a:disabled'), "a[0]")
    expect_equal(xpath('a:checked'), "a[0]")
    expect_equal(xpath('a:required'), "a[0]")
    expect_equal(xpath('a:optional'), "a[0]")
})

test_that(":has() generates correct XPath", {
    expect_equal(xpath("div:has(p)"),
                 "div[.//*[name() = 'p']]")
    expect_equal(xpath("div:has(.foo)"),
                 "div[.//*[@class and contains(concat(' ', normalize-space(@class), ' '), ' foo ')]]")
    expect_equal(xpath("section:has(#main)"),
                 "section[.//*[@id = 'main']]")
    expect_equal(xpath("form:has([required])"),
                 "form[.//*[@required]]")
    expect_equal(xpath("div:has(p, span)"),
                 "div[.//*[name() = 'p'] | .//*[name() = 'span']]")
    expect_equal(xpath("div:has(p):has(span)"),
                 "div[.//*[name() = 'p'] and .//*[name() = 'span']]")
    expect_equal(xpath("*:has(img)"),
                 "*[.//*[name() = 'img']]")
    expect_equal(xpath("section:has(div.content)"),
                 "section[.//*[@class and contains(concat(' ', normalize-space(@class), ' '), ' content ') and name() = 'div']]")

    # Leading combinators (selectors-4 relative selectors)
    expect_equal(xpath("e:has(> img)"),
                 "e[child::*[name() = 'img']]")
    expect_equal(xpath("e:has(~ p)"),
                 "e[following-sibling::*[name() = 'p']]")
    expect_equal(xpath("e:has(+ p)"),
                 "e[following-sibling::*[1][name() = 'p']]")
    expect_equal(xpath("e:has(> a, ~ p)"),
                 "e[child::*[name() = 'a'] | following-sibling::*[name() = 'p']]")
    expect_equal(xpath("e:has(> .foo)"),
                 "e[child::*[@class and contains(concat(' ', normalize-space(@class), ' '), ' foo ')]]")
    expect_equal(xpath("e:has(+ p.foo)"),
                 "e[following-sibling::*[1][@class and contains(concat(' ', normalize-space(@class), ' '), ' foo ') and name() = 'p']]")

    # prefixed names stay node tests, resolved through the namespace map
    # like a top-level 'svg|g' rather than by comparing prefixes as strings
    expect_equal(xpath("e:has(svg|g)"),
                 "e[.//svg:g]")
    expect_equal(xpath("e:has(> svg|g)"),
                 "e[child::svg:g]")
    expect_equal(xpath("e:has(+ svg|g)"),
                 "e[following-sibling::*[1][self::svg:g]]")
})

test_that("nested :not() works (Selectors Level 4)", {
    expect_equal(xpath(':not(:not(a))'),
                 "*[not(not(name() = 'a'))]")
    expect_equal(xpath('e:is(:not(f))'),
                 "e[not(name() = 'f')]")
    expect_equal(xpath('e:has(:not(f))'),
                 "e[.//*[not(name() = 'f')]]")
})

test_that(":where() and :is() generate correct XPath", {
    # :is()/:matches() share the translation.
    expect_equal(xpath("div:where(p)"),
                 "div[name() = 'p']")
    expect_equal(xpath("div:where(.foo)"),
                 "div[@class and contains(concat(' ', normalize-space(@class), ' '), ' foo ')]")
    expect_equal(xpath("section:where(#main)"),
                 "section[@id = 'main']")
    expect_equal(xpath("input:where([required])"),
                 "input[@required]")
    expect_equal(xpath("div:where(p, span)"),
                 "div[name() = 'p' or name() = 'span']")
    expect_equal(xpath("*:where(div.content)"),
                 "*[@class and contains(concat(' ', normalize-space(@class), ' '), ' content ') and name() = 'div']")
    # Chained :where()s AND together, so this can never match
    expect_equal(xpath("div:where(p):where(span)"),
                 "div[name() = 'p' and name() = 'span']")
    expect_equal(xpath("e:is(.a):is(.b)"),
                 "e[@class and contains(concat(' ', normalize-space(@class), ' '), ' a ') and @class and contains(concat(' ', normalize-space(@class), ' '), ' b ')]")
    # Alternatives stay grouped: they AND with conditions before and after
    # the pseudo-class instead of OR-ing across the whole compound
    expect_equal(xpath("e.warning:is(.a, .b)"),
                 "e[@class and contains(concat(' ', normalize-space(@class), ' '), ' warning ') and (@class and contains(concat(' ', normalize-space(@class), ' '), ' a ') or @class and contains(concat(' ', normalize-space(@class), ' '), ' b '))]")
    expect_equal(xpath("e.warning:where(f, g)"),
                 "e[@class and contains(concat(' ', normalize-space(@class), ' '), ' warning ') and (name() = 'f' or name() = 'g')]")
    expect_equal(xpath(":is(f, g):first-child"),
                 "*[(name() = 'f' or name() = 'g') and count(preceding-sibling::*) = 0]")
    # prefixed names stay node tests (see the :has() pins)
    expect_equal(xpath("e:is(svg|g)"), "e[self::svg:g]")
    expect_equal(xpath("e:not(svg|g)"), "e[not(self::svg:g)]")
    expect_equal(xpath("e:is(svg|*)"), "e[self::svg:*]")
    expect_equal(xpath("*:where(.highlight)"),
                 "*[@class and contains(concat(' ', normalize-space(@class), ' '), ' highlight ')]")
    expect_equal(xpath("div:where(.foo, .bar)"),
                 "div[@class and contains(concat(' ', normalize-space(@class), ' '), ' foo ') or @class and contains(concat(' ', normalize-space(@class), ' '), ' bar ')]")
    expect_equal(xpath("p:where(.highlight, #special, [data-key])"),
                 "p[@class and contains(concat(' ', normalize-space(@class), ' '), ' highlight ') or @id = 'special' or @data-key]")
    expect_equal(xpath("div:is(p)"), "div[name() = 'p']")
    expect_equal(xpath("div:matches(p)"), "div[name() = 'p']")
    # A universal argument makes the list a no-op constraint
    expect_equal(xpath("div:is(a, *)"), "div")
    expect_equal(xpath("div:where(a, *)"), "div")
})

test_that("complex selectors work inside functional pseudo-classes", {
    # :is()/:not() and the nth 'of S' lists match their argument at the
    # candidate element, so each combinator becomes an existence test
    # through the reversed axis; :has() looks forward, extending its path
    # compound by compound. (The full combinator/nesting matrix is pinned
    # in the Rust unit tests.)
    expect_equal(xpath("e:is(a b)"),
                 "e[name() = 'b' and ancestor::*[name() = 'a']]")
    expect_equal(xpath("e:is(a > b ~ c)"),
                 "e[name() = 'c' and preceding-sibling::*[name() = 'b' and parent::*[name() = 'a']]]")
    expect_equal(xpath("e:not(a + b)"),
                 "e[not(name() = 'b' and preceding-sibling::*[1][name() = 'a'])]")
    expect_equal(xpath("e:is(a b, c)"),
                 "e[name() = 'b' and ancestor::*[name() = 'a'] or name() = 'c']")
    expect_equal(xpath("e:has(a > b)"),
                 "e[.//*[name() = 'a']/*[name() = 'b']]")
    expect_equal(xpath("e:has(~ a + b)"),
                 "e[following-sibling::*[name() = 'a']/following-sibling::*[1][name() = 'b']]")
    expect_equal(xpath("e:nth-child(2n of a b)"),
                 "e[(count(preceding-sibling::*[name() = 'b' and ancestor::*[name() = 'a']]) +1) mod 2 = 0 and name() = 'b' and ancestor::*[name() = 'a']]")
})

test_that(":scope anchors the expression at the context node", {
    # A leading :scope compound moves onto the self:: axis and replaces
    # the prefix: the scope is the node the XPath is evaluated from.
    expect_equal(css_to_xpath(":scope"), "self::*")
    expect_equal(css_to_xpath(":scope > a"), "self::*/a")
    expect_equal(css_to_xpath(":scope a"), "self::*//a")
    expect_equal(css_to_xpath(":scope + a"),
                 "self::*/following-sibling::*[1][self::a]")
    # Other simple selectors in the compound constrain the context node.
    expect_equal(css_to_xpath("div:scope"), "self::div")
    expect_equal(css_to_xpath(":scope.foo > a"),
                 "self::*[@class and contains(concat(' ', normalize-space(@class), ' '), ' foo ')]/a")
    # Per selector group: other groups keep the prefix.
    expect_equal(css_to_xpath("a, :scope > b"),
                 "descendant-or-self::a | self::*/b")
})

test_that(":nth-child(an+b of S) generates correct XPath", {
    expect_equal(xpath("div:nth-child(2 of .foo)"),
                 paste0("div[count(preceding-sibling::*[@class and contains(concat(' ', normalize-space(@class), ' '), ' foo ')]) = 1",
                        " and @class and contains(concat(' ', normalize-space(@class), ' '), ' foo ')]"))
    expect_equal(xpath("li:nth-last-child(3 of .important)"),
                 paste0("li[count(following-sibling::*[@class and contains(concat(' ', normalize-space(@class), ' '), ' important ')]) = 2",
                        " and @class and contains(concat(' ', normalize-space(@class), ' '), ' important ')]"))
    expect_equal(xpath("li:nth-child(n of .item)"),
                 "li[@class and contains(concat(' ', normalize-space(@class), ' '), ' item ')]")
    expect_equal(xpath("li:nth-child(-n of .item)"),
                 "li[0 and @class and contains(concat(' ', normalize-space(@class), ' '), ' item ')]")
    expect_equal(xpath("div:nth-child(2 of div.foo)"),
                 paste0("div[count(preceding-sibling::*[@class and contains(concat(' ', normalize-space(@class), ' '), ' foo ') and name() = 'div']) = 1",
                        " and @class and contains(concat(' ', normalize-space(@class), ' '), ' foo ') and name() = 'div']"))
    # A universal argument makes the list match everything, like a plain :nth-child
    expect_equal(xpath("li:nth-child(2 of .foo, *)"),
                 "li[count(preceding-sibling::*) = 1]")
    expect_equal(xpath("li:nth-last-child(2 of .foo, *)"),
                 "li[count(following-sibling::*) = 1]")
})

test_that(":lang() and :dir() generate correct XPath", {
    # Generic: XPath's lang() does language-range matching natively.
    expect_equal(xpath("e:lang(en)"), "e[lang('en')]")
    expect_equal(xpath("e:lang('en')"), "e[lang('en')]")
    expect_equal(xpath("e:lang(en-*)"), "e[lang('en')]")
    expect_equal(xpath("e:lang(*)"), "e[true()]")
    expect_equal(xpath("e:lang(en, fr)"), "e[lang('en') or lang('fr')]")
    # :dir() is never statically matchable, in any translator: resolved
    # directionality needs runtime bidi resolution, and a nearest-@dir
    # approximation is deliberately not attempted.
    expect_equal(xpath("e:dir(ltr)"), "e[0]")
    expect_equal(css_to_xpath("e:dir(rtl)", "", "html"), "e[0]")
    expect_equal(css_to_xpath("e:dir(ltr)", "", "xhtml"), "e[0]")
    # HTML/xhtml: nearest lang-attributed ancestor, lowercased prefix.
    lang_test <- function(prefix) {
        paste0("ancestor-or-self::*[@lang][1][starts-with(concat(",
               "translate(@lang, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', ",
               "'abcdefghijklmnopqrstuvwxyz'), '-'), '", prefix, "')]")
    }
    expect_equal(css_to_xpath("e:lang(EN)", "", "html"),
                 paste0("e[", lang_test("en-"), "]"))
    expect_equal(css_to_xpath("e:lang(en-*)", "", "xhtml"),
                 paste0("e[", lang_test("en-"), "]"))
    expect_equal(css_to_xpath("e:lang(*)", "", "html"),
                 "e[ancestor-or-self::*[@lang]]")
})

test_that("HTML translator overrides dynamic pseudo-classes", {
    h <- function(css) css_to_xpath(css, prefix = "", translator = "html")
    expect_equal(h("a:link"),
                 "a[@href and (name(.) = 'a' or name(.) = 'link' or name(.) = 'area')]")
    # :any-link is :link plus :visited; with no visited state in a static
    # document the two coincide, so they share a translation.
    expect_equal(h("a:any-link"), h("a:link"))
    expect_equal(h("input:checked"),
                 paste0("input[(@selected and name(.) = 'option') or ",
                        "(@checked and (name(.) = 'input' or name(.) = 'command')",
                        "and (@type = 'checkbox' or @type = 'radio'))]"))
    # Non-overridden dynamic pseudos still never match.
    expect_equal(h("a:hover"), "a[0]")
    expect_equal(h("a:visited"), "a[0]")
    # The xhtml translator shares the HTML overrides without lowercasing.
    expect_equal(css_to_xpath("A:link", "", "xhtml"),
                 "A[@href and (name(.) = 'a' or name(.) = 'link' or name(.) = 'area')]")
    # :enabled/:disabled have long HTML conditions; pin their shape.
    expect_match(h("input:disabled"), "ancestor::fieldset\\[@disabled\\]")
    expect_match(h("input:enabled"), "not \\(@disabled or ancestor::fieldset\\[@disabled\\]\\)")
})

test_that("translation of unsafe XPath names works", {
    charsets <- localeToCharset()
    if (!anyNA(charsets) && charsets[1] == "UTF-8") {
        expect_equal(xpath('di\ua0v'),
                     "*[name() = 'di\ua0v']")
        expect_equal(xpath('[h\ua0ref]'),
                     "*[attribute::*[name() = 'h\ua0ref']]")
    }
    expect_equal(xpath('di\\[v'),
                 "*[name() = 'di[v']")
    expect_equal(xpath('[h\\]ref]'),
                 "*[attribute::*[name() = 'h]ref']]")
    # Unicode escapes are decoded to the characters they represent,
    # in idents, hashes, and strings alike
    expect_equal(xpath("#\\31 23"), "*[@id = '123']")
    expect_equal(xpath("\\31 23"), "*[name() = '123']")
    expect_equal(xpath("[\\31 23]"),
                 "*[attribute::*[name() = '123']]")
    expect_equal(xpath("e[foo='\\31 23']"), "e[@foo = '123']")
    expect_equal(xpath("e[foo='x\\79 z']"), "e[@foo = 'xyz']")
    # Hex digits in escapes are case-insensitive
    expect_equal(xpath("e[foo='\\4a']"), "e[@foo = 'J']")
    expect_equal(xpath("e[foo='\\4A']"), "e[@foo = 'J']")
    # An escaped backslash yields a literal backslash; what follows it
    # must not be re-processed as another escape
    expect_equal(xpath("e[foo='x\\\\79 z']"), "e[@foo = 'x\\79 z']")
})

test_that("unsupported constructs error informatively", {
    # The non-standard [a!=b] and :contains() are not supported.
    expect_error(xpath('e[foo!="bar"]'), "parse")
    expect_error(xpath('e:contains("foo")'))
    # Malformed case-sensitivity flags error.
    expect_error(xpath('[rel i]'))
    expect_error(xpath('[rel=stylesheet k]'))
    expect_error(xpath('[rel=stylesheet i i]'))
    # Parse failures name the selector.
    expect_error(xpath('e:'), "e:")
    # Pseudo-elements error.
    expect_error(xpath('e::before'))
    expect_error(xpath('e:first-line'))
    # Unknown pseudo-classes error.
    expect_error(xpath('e:unknown-pseudo'))
    # So do known pseudo-classes outside the never-match policy (form
    # validity and state could be at least partially translated some day,
    # and erroring keeps typos loud).
    expect_error(xpath('e:valid'))
    expect_error(xpath('e:read-only'))
    expect_error(xpath('e:placeholder-shown'))
    # The column combinator and the grid-structural pseudo-classes have
    # no XPath 1.0 translation (column membership is colspan/rowspan
    # layout arithmetic); pipes in strings, escapes, and comments are
    # still fine.
    expect_error(xpath('col || td'), "column combinator")
    expect_error(xpath('e:nth-col(2)'))
    expect_error(xpath('e:nth-last-col(2n)'))
    expect_equal(xpath('[foo="a||b"]'), "*[@foo = 'a||b']")
    expect_equal(xpath('a /* || */ b'), "a//b")
    # :scope is supported in the leftmost compound only, and never inside
    # functional pseudo-class arguments.
    expect_error(xpath('a :scope'))
    expect_error(xpath('a > :scope'))
    expect_error(xpath('e:is(:scope)'))
    expect_error(xpath('e:has(:scope)'))
    # Leading combinators are :has()-only; dangling and doubled
    # combinators are parse errors everywhere.
    expect_error(xpath('e:is(> a)'))
    expect_error(xpath('e:where(~ a)'))
    expect_error(xpath('e:not(+ a)'))
    expect_error(xpath('e:has(> > a)'))
    expect_error(xpath('e:has(>)'))
    expect_error(xpath('e:has(a >)'))
    # Nested :has() is rejected (selectors-4).
    expect_error(xpath('e:has(a:has(b))'))
    expect_error(xpath('e:has(> a:has(b))'))
    # of-type pseudo-classes on '*' are not implemented, including
    # compounds that leave the type implicit ('.foo' is '*.foo').
    expect_error(xpath('*:first-of-type'))
    expect_error(xpath('*:nth-of-type(2)'))
    expect_error(xpath('.foo:first-of-type'))
    expect_error(xpath('[bar]:only-of-type'))
    # :lang()/:dir() argument validation; a lone '-' is not a valid ident.
    expect_error(xpath('e:lang()'))
    expect_error(xpath('e:lang(5)'))
    expect_error(xpath('e:lang(-)'))
    # An+B must be whitespace-exact and integer-valued.
    expect_error(xpath('e:nth-child(3 7)'))
    expect_error(xpath('e:nth-child(2 n)'))
    expect_error(xpath('e:nth-child(2.5)'))
    expect_error(xpath('e:nth-child(2e1)'))
})

test_that("css_to_xpath vectorises arguments", {
    expect_equal(css_to_xpath("a b"), "descendant-or-self::a//b")
    expect_equal(css_to_xpath("a b", prefix = ""), "a//b")
    expect_equal(css_to_xpath("a b", prefix = c("descendant-or-self::", "")),
                 c("descendant-or-self::a//b", "a//b"))
    expect_equal(css_to_xpath(c("a b", "b c"), prefix = ""), c("a//b", "b//c"))
})

test_that("css_to_xpath handles bad arguments", {
    # must have a selector arg provided
    expect_error(css_to_xpath(), "A valid selector (character vector) must be provided.", fixed = TRUE)
    expect_error(css_to_xpath(NULL), "A valid selector (character vector) must be provided.", fixed = TRUE)

    # should complain about incorrect vector type
    expect_error(css_to_xpath(1), "The 'selector' argument.*")
    expect_error(css_to_xpath("a", prefix = 1), "The 'prefix' argument.*")
    expect_error(css_to_xpath("a", translator = 1), "The 'translator' argument.*")

    # NAs error rather than silently shifting how arguments pair up
    expect_error(css_to_xpath(c("a", NA)), "NA values are not allowed in the 'selector' argument")
    expect_error(css_to_xpath("a", prefix = c("", NA)), "NA values are not allowed in the 'prefix' argument")
    expect_error(css_to_xpath("a", translator = c("generic", NA)), "NA values are not allowed in the 'translator' argument")
    expect_error(css_to_xpath(NA_character_), "NA values are not allowed in the 'selector' argument")
    expect_error(css_to_xpath("a", prefix = NA_character_), "NA values are not allowed in the 'prefix' argument")
    expect_error(css_to_xpath("a", translator = NA_character_), "NA values are not allowed in the 'translator' argument")
    expect_error(css_to_xpath(c("a", "b", "c"), prefix = c("p1//", NA, "p3//")),
                 "NA values are not allowed in the 'prefix' argument")

    # performs partial matching
    expect_equal(css_to_xpath("a", translator = "g"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = "gEnErIC"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = "h"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = "x"), "descendant-or-self::a")
    expect_equal(css_to_xpath("a", translator = c("g", "h", "x")),
                 rep("descendant-or-self::a", 3))

    # errors anything not matching generic, html, xhtml
    expect_error(css_to_xpath("a", translator = ""), "'arg' should be one of.*")
    expect_error(css_to_xpath("a", translator = "a"), "'arg' should be one of.*")
    expect_error(css_to_xpath("a", translator = c("generic", "a")), "'arg' should be one of.*")
})
