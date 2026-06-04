# Ported from selectr's tests/testthat/test-querySelector-default.R (sjp/selectr@9ed9bb2, by
# Simon Potter), adapted for selectrs: testthat edition-3 idioms
# (expect_equal instead of expect_that/equals, no context()), and
# guarded by skip_if_not_installed()

test_that("querySelector methods present an error on non-XML/xml2 objects", {
    expect_error(querySelector(list()), "The object given to querySelector.*")
    expect_error(querySelectorAll(list()), "The object given to querySelector.*")
    expect_error(querySelectorNS(list()), "The object given to querySelector.*")
    expect_error(querySelectorAllNS(list()), "The object given to querySelector.*")
})
