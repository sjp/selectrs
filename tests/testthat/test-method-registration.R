test_that("method registration occurs correctly", {
    skip_if_not_installed("XML")
    skip_if_not_installed("xml2")

    library(XML)
    xdoc <- xmlParse("<svg><circle /></svg>")

    library(xml2)
    x2doc <- read_xml("<svg><circle /></svg>")

    expect_no_error(querySelector(xdoc, "circle"))
    expect_no_error(querySelector(x2doc, "circle"))
})
