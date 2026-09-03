# selectrs 0.1.0

First release. `selectrs` is a standalone, API-compatible port of
`selectr`, with CSS selector parsing and XPath translation performed in
Rust by the `css-to-xpath` crate.

* `css_to_xpath()` translates a CSS selector into an equivalent XPath
  expression.

* `querySelector()` and `querySelectorAll()` query `XML` and `xml2`
  documents and nodes with a CSS selector; `querySelectorNS()` and
  `querySelectorAllNS()` do the same in a namespaced document.

* Errors are classed conditions. Each carries both its `selectrs_*` name
  and the matching `selectr_*` one, and the fields `selectr` names `pos`
  and `feature` alongside `column` and `construct`, so a handler written
  against `selectr` fires unchanged.
