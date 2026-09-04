# selectrs

[![License (3-Clause BSD)](https://img.shields.io/badge/license-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause) [![r-cmd-check](https://github.com/sjp/selectrs/actions/workflows/r-cmd-check.yaml/badge.svg)](https://github.com/sjp/selectrs/actions/workflows/r-cmd-check.yaml) [![rust-checks](https://github.com/sjp/selectrs/actions/workflows/rust-checks.yaml/badge.svg)](https://github.com/sjp/selectrs/actions/workflows/rust-checks.yaml)

`selectrs` is a package which makes working with HTML and XML documents easier. It does this by performing translation of CSS selectors into XPath expressions so that you can query `XML` and `xml2` documents easily.

It is a standalone, API-compatible port of the [selectr](https://github.com/sjp/selectr) package with the parsing and translation core implemented in Rust by the [css-to-xpath](https://crates.io/crates/css-to-xpath) crate, which builds on Servo's [cssparser](https://crates.io/crates/cssparser) and [selectors](https://crates.io/crates/selectors) crates. Queries return the same results as `selectr`, but faster.

``` r
library(selectrs)
xpath <- css_to_xpath("#selectrs")
xpath
#> [1] "descendant-or-self::*[@id = 'selectrs']"
```

## Installation

`selectrs` is not yet on CRAN. It requires R >= 4.2. Because the package compiles its Rust core from source, you will need a working Rust toolchain (`cargo` and `rustc` >= 1.88) in addition to the usual R build tools. See <https://www.rust-lang.org/tools/install> for installation instructions.

### Install the development version from GitHub

``` r
# install.packages("remotes")
remotes::install_github("sjp/selectrs")
```

## Overview

The key functions in `selectrs` are:

* Translate a CSS selector into an XPath expression with `css_to_xpath()`.

* Query an `XML` or `xml2` document with `querySelector()` and its variants.

    * Find the first matching node with `querySelector()`.

    * Find all matching nodes with `querySelectorAll()`.

    * Find the first matching node in a namespaced document with `querySelectorNS()`.

    * Find all matching nodes in a namespaced document with `querySelectorAllNS()`.

## Examples

Here is a simple example to demonstrate how to query an `XML` or `xml2` document with `querySelector()`.

``` r
library(selectrs)
xmlText <- '<foo><bar><baz id="first"/></bar><baz id="second"/></foo>'

library(XML)
doc <- xmlParse(xmlText)
querySelector(doc, "baz")
#> <baz id="first"/>
querySelectorAll(doc, "baz")
#> [[1]]
#> <baz id="first"/>
#>
#> [[2]]
#> <baz id="second"/>
#>
#> attr(,"class")
#> [1] "XMLNodeSet"

library(xml2)
doc <- read_xml(xmlText)
querySelector(doc, "baz")
#> {xml_node}
#> <baz id="first">
querySelectorAll(doc, "baz")
#> {xml_nodeset (2)}
#> [1] <baz id="first"/>
#> [2] <baz id="second"/>
```

## Relationship to `selectr`

`selectrs` aims to be a drop-in replacement for `selectr`: the exported functions and their arguments are the same, and queries match the same nodes. The generated XPath expressions are equivalent, though not always byte-identical (for example, the Rust core parenthesises predicates more eagerly). The main difference is under the hood — selector parsing and translation happen in Rust rather than R, which makes translation substantially faster (blazingly fast).

`selectr` is itself a translation of the Python package [cssselect](https://github.com/scrapy/cssselect). See `inst/AUTHORS` for the full list of authors and copyright holders of ported and vendored code.
