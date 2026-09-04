# The three condition classes, each carried under its selectr name too so
# that a handler written against selectr fires here.
parseClass <- c("selectrs_parse_error", "selectr_parse_error",
                "selectrs_error", "selectr_error", "error", "condition")
translationClass <- c("selectrs_translation_error", "selectr_translation_error",
                      "selectrs_error", "selectr_error", "error", "condition")
argumentClass <- c("selectrs_argument_error", "selectr_argument_error",
                   "selectrs_error", "selectr_error", "error", "condition")

test_that("a syntax error is a selectrs_parse_error carrying the column", {
    e <- tryCatch(css_to_xpath("div >"), error = identity)
    expect_identical(class(e), parseClass)
    expect_equal(e$selector, "div >")
    expect_equal(e$index, 1L)
    expect_equal(e$column, 6L)
    expect_null(e$construct)
    expect_null(conditionCall(e))
    # selectr's name for the column, carried so its handlers keep working
    expect_equal(e$pos, e$column)
    # the caret block is still part of the message
    expect_match(conditionMessage(e), "Unable to parse the CSS selector \"div >\"",
                 fixed = TRUE)
})

test_that("the reported column counts characters, in any encoding", {
    e <- tryCatch(css_to_xpath("日本 >"), error = identity)
    expect_equal(e$column, 5L)

    e <- tryCatch(css_to_xpath(iconv("café >", "UTF-8", "latin1")),
                  error = identity)
    expect_equal(e$column, 7L)
    # the field holds the UTF-8 translation that was parsed
    expect_equal(e$selector, "café >")
    expect_equal(Encoding(e$selector), "UTF-8")
})

test_that("an unsupported construct is a selectrs_translation_error naming it", {
    e <- tryCatch(css_to_xpath("*:first-of-type"), error = identity)
    expect_identical(class(e), translationClass)
    expect_equal(e$selector, "*:first-of-type")
    expect_equal(e$index, 1L)
    expect_equal(e$construct, "an of-type pseudo-class on the universal selector `*`")
    expect_null(conditionCall(e))
    expect_match(conditionMessage(e), e$construct, fixed = TRUE)
    # this one is only recognised once the selector has been parsed, so
    # there is no position to report
    expect_null(e$column)
    # selectr's names for the two fields, carried alongside; feature holds
    # this package's phrase rather than selectr's short descriptor
    expect_equal(e$feature, e$construct)
    expect_null(e$pos)
})

test_that("a construct found in the selector text reports its column", {
    e <- tryCatch(css_to_xpath("col || td"), error = identity)
    expect_identical(class(e), translationClass)
    expect_equal(e$construct, "the `||` column combinator")
    expect_equal(e$column, 5L)
    expect_equal(e$pos, 5L)
    expect_equal(e$feature, e$construct)

    # counted in characters, like the parse error column
    e <- tryCatch(css_to_xpath("日本 || td"), error = identity)
    expect_equal(e$column, 4L)
})

test_that("the two translation failures are distinguishable from each other", {
    kind <- function(selector) {
        tryCatch(css_to_xpath(selector),
                 selectrs_parse_error = function(e) "parse",
                 selectrs_translation_error = function(e) "translation",
                 selectrs_argument_error = function(e) "argument",
                 error = function(e) "plain")
    }
    expect_equal(kind("div >"), "parse")
    expect_equal(kind("*:first-of-type"), "translation")
    expect_equal(kind(NA_character_), "argument")
})

test_that("the parse/translation line falls where the documentation says", {
    kind <- function(selector) {
        tryCatch(css_to_xpath(selector),
                 selectrs_parse_error = function(e) "parse",
                 selectrs_translation_error = function(e) "translation",
                 error = function(e) "plain")
    }
    # An unknown or unsupported pseudo-class or pseudo-element is
    # malformed input to this parser, where selectr parses any `:name`
    # and rejects it when translating.
    for (selector in c("e:frobnicate", "a:first_child", "::before",
                       "a::first-line", "a:contains(x)", "td:nth-col(2)",
                       ":nth-last-col(2)", ":host"))
        expect_equal(kind(selector), "parse", info = selector)

    # These two are well-formed CSS with no XPath, and go the other way.
    expect_equal(kind("col || td"), "translation")
    expect_equal(kind("& a"), "translation")
})

test_that("the documented translation limits are the ones enforced", {
    nested <- function(depth) paste0(strrep(":not(", depth), "a",
                                     strrep(")", depth))
    expect_type(css_to_xpath(nested(32)), "character")
    e <- tryCatch(css_to_xpath(nested(33)), error = identity)
    expect_identical(class(e), translationClass)
    expect_equal(e$construct,
                 "functional pseudo-classes nested more than 32 levels deep")

    ofNested <- function(depth, alternatives = 1L) {
        s <- paste0(sprintf(".c%d", seq_len(alternatives)), collapse = ",")
        for (i in seq_len(depth))
            s <- paste0("p:nth-child(2n of ", s, ")")
        s
    }
    expect_type(css_to_xpath(ofNested(8)), "character")
    e <- tryCatch(css_to_xpath(ofNested(9)), error = identity)
    expect_identical(class(e), translationClass)
    expect_equal(e$construct,
                 "`An+B of S` selector lists nested more than 8 levels deep")

    # The size cap behind the `of S` depth limit: each level writes the
    # list out twice, so a wide enough list reaches it from within the
    # permitted depth.
    e <- tryCatch(css_to_xpath(ofNested(7, 400)), error = identity)
    expect_identical(class(e), translationClass)
    expect_equal(e$construct,
                 "an `An+B of S` selector list translating to more than 1048576 bytes")
})

test_that("handlers written for selectr's class names fire", {
    kind <- function(selector) {
        tryCatch(css_to_xpath(selector),
                 selectr_parse_error = function(e) "parse",
                 selectr_translation_error = function(e) "translation",
                 selectr_argument_error = function(e) "argument",
                 error = function(e) "plain")
    }
    expect_equal(kind("div >"), "parse")
    expect_equal(kind("*:first-of-type"), "translation")
    expect_equal(kind(NA_character_), "argument")

    family <- function(selector) {
        tryCatch(css_to_xpath(selector),
                 selectr_error = function(e) "selectr",
                 error = function(e) "plain")
    }
    expect_equal(family("div >"), "selectr")
    expect_equal(family("*:first-of-type"), "selectr")
    expect_equal(family(NA_character_), "selectr")

    e <- tryCatch(css_to_xpath("div >"), error = identity)
    expect_s3_class(e, "selectr_parse_error")
    expect_s3_class(e, "selectr_error")
    # selectrs' own name is still the one the condition prints under
    expect_identical(class(e)[1L], "selectrs_parse_error")
})

test_that("a vectorised call reports which element failed", {
    e <- tryCatch(css_to_xpath(c("a", "div >", "b")), error = identity)
    expect_equal(e$index, 2L)
    expect_equal(e$selector, "div >")

    e <- tryCatch(css_to_xpath(c("a", "b", "*:first-of-type")), error = identity)
    expect_equal(e$index, 3L)

    # the failing element is found after recycling, not before it
    e <- tryCatch(css_to_xpath("div >", prefix = c("", "//")), error = identity)
    expect_equal(e$index, 1L)
})

test_that("argument errors from css_to_xpath are selectrs_argument_errors", {
    classed <- function(expr) {
        e <- tryCatch(expr, error = identity)
        identical(class(e), argumentClass)
    }
    expect_true(classed(css_to_xpath()))
    expect_true(classed(css_to_xpath(NULL)))
    expect_true(classed(css_to_xpath(1)))
    expect_true(classed(css_to_xpath("a", prefix = 1)))
    expect_true(classed(css_to_xpath("a", translator = 1)))
    expect_true(classed(css_to_xpath(NA_character_)))
    expect_true(classed(css_to_xpath(character(0))))
    expect_true(classed(css_to_xpath("a", translator = "nosuch")))
    expect_true(classed(css_to_xpath(c("a", "b"),
                                     translator = c("nosuch", "either"))))

    # the message names the argument the caller wrote, not match.arg()'s
    # own formal, and echoes every value that was rejected
    e <- tryCatch(css_to_xpath("a", translator = "nosuch"), error = identity)
    expect_match(conditionMessage(e), "'translator' must be one of")
    expect_match(conditionMessage(e), "not \"nosuch\"", fixed = TRUE)
    e <- tryCatch(css_to_xpath(c("a", "b"), translator = c("nosuch", "either")),
                  error = identity)
    expect_match(conditionMessage(e), "not \"nosuch\", \"either\"", fixed = TRUE)
    expect_null(conditionCall(e))
})

test_that("argument errors from the query functions are classed too", {
    expectArgumentError <- function(expr) {
        e <- tryCatch(expr, error = identity)
        expect_identical(class(e), argumentClass)
    }
    expectArgumentError(querySelector(1, "a"))
    expectArgumentError(querySelectorAll(1, "a"))
    expectArgumentError(querySelectorNS(1, "a", c(a = "u")))
    expectArgumentError(querySelectorAllNS(1, "a", c(a = "u")))
    expectArgumentError(validateSelector(c("a", "b")))
    expectArgumentError(formatNS(1))
    expectArgumentError(formatNS(c(a = "")))
    expectArgumentError(formatNS(c("a b" = "urn:a")))
})

test_that("a failing selector reaching the query functions keeps its class", {
    skip_if_not_installed("xml2")
    doc <- xml2::read_xml("<a><b/></a>")
    e <- tryCatch(querySelector(doc, "div >"), error = identity)
    expect_identical(class(e), parseClass)
    e <- tryCatch(querySelectorAll(doc, "*:first-of-type"), error = identity)
    expect_identical(class(e), translationClass)
})

test_that("the Rust boundary reports a failure rather than throwing", {
    # css_to_xpath() turns this list into a condition; the internal
    # function itself returns it, so a translation failure is not an
    # unwind across the FFI boundary
    failure <- selectrs:::css_to_xpath_rust("div >", "", "generic")
    expect_type(failure, "list")
    expect_equal(failure$kind, "parse")
    expect_equal(failure$column, 6L)
    expect_equal(failure$index, 1L)

    failure <- selectrs:::css_to_xpath_rust("*:first-of-type", "", "generic")
    expect_equal(failure$kind, "unsupported")
    expect_type(failure$construct, "character")
    expect_false("column" %in% names(failure))

    failure <- selectrs:::css_to_xpath_rust("col || td", "", "generic")
    expect_equal(failure$kind, "unsupported")
    expect_equal(failure$column, 5L)
})

test_that("a long selector is abbreviated so the message stays readable", {
    selector <- paste0(paste(rep("a.b", 10000), collapse = " "), " >")
    e <- tryCatch(css_to_xpath(selector), error = identity)
    message <- conditionMessage(e)

    # R truncates a printed error at options("warning.length"), so a
    # message built from the whole selector would lose the caret line
    expect_lt(nchar(message, "bytes"), getOption("warning.length"))
    expect_match(message, "\n  | ", fixed = TRUE)
    expect_match(message, "a.b >", fixed = TRUE)
    # nothing is lost: the condition still carries the whole selector
    expect_equal(e$selector, selector)
    expect_equal(e$column, nchar(selector) + 1L)
})

test_that("an unsupported construct on a long selector does not echo it", {
    selector <- paste0(paste(rep("a.b", 500), collapse = " "),
                       " *:first-of-type")
    e <- tryCatch(css_to_xpath(selector), error = identity)
    message <- conditionMessage(e)

    expect_lt(nchar(message, "bytes"), getOption("warning.length"))
    expect_match(message, e$construct, fixed = TRUE)
    expect_equal(e$selector, selector)
})

test_that("a detail quoting the offending token is truncated too", {
    # the parse detail embeds the token it choked on, so a selector
    # holding a huge identifier would otherwise produce a huge detail
    token <- strrep("z", 5000)
    e <- tryCatch(css_to_xpath(paste0(":nth-child(", token, ")")),
                  error = identity)
    expect_lt(nchar(conditionMessage(e), "bytes"), getOption("warning.length"))
    expect_match(conditionMessage(e), "unexpected `zz", fixed = TRUE)
    expect_false(grepl(token, conditionMessage(e), fixed = TRUE))
})

test_that("the caret lands under the reported column", {
    caretOffset <- function(selector) {
        e <- tryCatch(css_to_xpath(selector), error = identity)
        lines <- strsplit(conditionMessage(e), "\n", fixed = TRUE)[[1]]
        # the echo and the caret share the same "  | " gutter
        as.integer(regexpr("^", lines[[4]], fixed = TRUE)) - 5L
    }
    expect_equal(caretOffset("div >"), 5L)
    expect_equal(caretOffset("a["), 2L)
    # the caret is placed by display width, so a character two columns
    # wide moves it by two
    expect_equal(caretOffset("日本 !"), 5L)
    expect_equal(caretOffset("\U0001F600!"), 2L)
    # a tab is echoed as the single space it is aligned as
    expect_equal(caretOffset("\tdiv >"), 6L)
    # only the line the failure is on is echoed, so a selector written
    # over several lines does not break the gutter apart
    expect_equal(caretOffset("a,\nb >"), 3L)
})

test_that("a short selector is still quoted in full", {
    selector <- strrep("a.b ", 25)
    e <- tryCatch(css_to_xpath(paste0(selector, ">")), error = identity)
    expect_match(conditionMessage(e), selector, fixed = TRUE)
})
