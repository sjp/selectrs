# Named to run last. The tests reach XML and xml2 through XML:: and xml2::
# so that a test body sees only the selectrs API and whichever package it
# asked for; attaching one would let it mask a method or import that the
# package itself should have provided, and would do so silently.
test_that("no test attached XML or xml2", {
    expect_false(any(c("package:XML", "package:xml2") %in% search()))
})
