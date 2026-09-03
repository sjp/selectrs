#!/usr/bin/env Rscript
# Benchmark selectrs against selectr and print the tables used in
# BENCHMARKS.md.
#
# Run from the package root:  Rscript tools/benchmark.R
#
# Needs selectr, bench and xml2 installed. Only xml2 is in Suggests: the
# shipped test suite has to stay self-contained, so the other two are a
# requirement of this script rather than of the package.

for (pkg in c("selectr", "selectrs", "bench", "xml2"))
    if (!requireNamespace(pkg, quietly = TRUE))
        stop("tools/benchmark.R needs the ", pkg, " package installed.")

selectors <- c(
    `type`                  = "div",
    `class`                 = ".note",
    `id`                    = "#main",
    `attribute (presence)`  = "a[rel]",
    `attribute (prefix)`    = "a[href^='https://']",
    `descendant`            = "div p",
    `child + class`         = "div > p.note",
    `compound chain`        = "ul li a.external",
    `sibling`               = "h2 ~ p + span",
    `pseudo-class`          = "p:first-child",
    `nth-child (an+b)`      = "tr:nth-child(2n+1)",
    `negation`              = "input:not([type='hidden'])",
    `union (3 selectors)`   = "h1, h2, h3",
    `kitchen sink`          = "div#content > ul.menu li:nth-of-type(2) a[href$='.html']:not(.active)"
)

# 1,000 selectors with no repeats, which defeats both packages' per-call
# translation caches.
unique_selectors <-
    sprintf("div#id%d > ul.menu%d li:nth-child(%dn+%d) a[href^='/p%d']",
            1:1000, 1:1000, 1:1000 %% 7 + 2, 1:1000 %% 5, 1:1000)

# Every selector in `selectors` matches at least one node in this document,
# so the two packages' XPath can be compared on what it selects rather than
# on how it is spelled.
doc <- xml2::read_html(paste0(
    "<html><body>",
    "<div id='main'>",
      "<h1>Title</h1>",
      "<h2>Section</h2>",
      "<p class='note'>first</p>",
      "<p>second</p>",
      "<span>adjacent</span>",
      "<h3>Sub</h3>",
      "<div><p>first child</p></div>",
      "<ul>",
        "<li><a class='external' rel='nofollow' href='https://example.com/a.html'>a</a></li>",
        "<li><a href='/b.html'>b</a></li>",
      "</ul>",
      "<table>",
        "<tr><td>1</td></tr><tr><td>2</td></tr><tr><td>3</td></tr>",
      "</table>",
      "<form>",
        "<input type='hidden' name='h'>",
        "<input type='checkbox' checked>",
      "</form>",
    "</div>",
    "<div id='content'>",
      "<ul class='menu'>",
        "<li><a href='/one.html'>one</a></li>",
        "<li><a href='/two.html'>two</a><a class='active' href='/three.html'>three</a></li>",
      "</ul>",
    "</div>",
    "</body></html>"))

# Correctness gate. The two packages are allowed to spell the XPath
# differently -- whitespace, and which redundant conjuncts get emitted,
# have both differed between selectr versions -- so what has to agree is
# the set of nodes the XPath selects.
check <- function(selectors, translator = "generic", must_match = TRUE) {
    same_string <- 0L
    for (s in selectors) {
        a <- selectr::css_to_xpath(s, translator = translator)
        b <- selectrs::css_to_xpath(s, translator = translator)
        ma <- xml2::xml_path(xml2::xml_find_all(doc, a))
        mb <- xml2::xml_path(xml2::xml_find_all(doc, b))
        if (!identical(ma, mb))
            stop(sprintf("%s selects different nodes\n  selectr:  %s\n  selectrs: %s",
                         s, a, b))
        if (must_match && !length(ma))
            stop(sprintf("%s matches nothing in the benchmark document", s))
        same_string <- same_string + identical(a, b)
    }
    cat(sprintf(
        "%d selectors select the same nodes, %d via identical XPath.\n",
        length(selectors), same_string))
}

check(selectors)
check("input:checked", translator = "html")
check(unique_selectors, must_match = FALSE)

# check = FALSE throughout: equality is the gate above, not string equality,
# which bench::mark() would insist on.
per_selector <- do.call(rbind, lapply(seq_along(selectors), function(i) {
    s <- selectors[[i]]
    res <- bench::mark(
        selectr  = selectr::css_to_xpath(s),
        selectrs = selectrs::css_to_xpath(s),
        min_iterations = 200, check = FALSE)
    data.frame(case = names(selectors)[i],
               selector = s,
               selectr_us  = as.numeric(res$median[1]) * 1e6,
               selectrs_us = as.numeric(res$median[2]) * 1e6)
}))
per_selector$speedup <- per_selector$selectr_us / per_selector$selectrs_us

cat("\n## Per-selector results\n\n")
cat("| Case | Selector | selectr (µs) | selectrs (µs) | Speedup |\n")
cat("|---|---|---:|---:|---:|\n")
cat(sprintf("| %s | `%s` | %.1f | %.1f | %.1fx |\n",
            per_selector$case, per_selector$selector, per_selector$selectr_us,
            per_selector$selectrs_us, per_selector$speedup), sep = "")
cat(sprintf("\n**Geometric mean speedup: %.1fx.**\n",
            exp(mean(log(per_selector$speedup)))))

# Repeating the 14 selectors to 1,000 elements exercises both packages'
# per-call caches; unique_selectors defeats them.
repeated <- rep(unname(selectors), length.out = 1000)
workloads <- list(
    `14 selectors, one call` = unname(selectors),
    `1,000 selectors (14 unique), one call` = repeated,
    `1,000 unique selectors, one call` = unique_selectors)

vectorized <- do.call(rbind, lapply(names(workloads), function(nm) {
    x <- workloads[[nm]]
    iters <- if (startsWith(nm, "1,000")) 20 else 200
    res <- bench::mark(
        selectr  = selectr::css_to_xpath(x),
        selectrs = selectrs::css_to_xpath(x),
        min_iterations = iters, check = FALSE)
    data.frame(workload = nm,
               selectr_us  = as.numeric(res$median[1]) * 1e6,
               selectrs_us = as.numeric(res$median[2]) * 1e6,
               selectr_alloc  = format(res$mem_alloc[1]),
               selectrs_alloc = format(res$mem_alloc[2]))
}))

html <- bench::mark(
    selectr  = selectr::css_to_xpath("input:checked", translator = "html"),
    selectrs = selectrs::css_to_xpath("input:checked", translator = "html"),
    min_iterations = 200, check = FALSE)
vectorized <- rbind(vectorized, data.frame(
    workload = "`input:checked` (`html` translator)",
    selectr_us  = as.numeric(html$median[1]) * 1e6,
    selectrs_us = as.numeric(html$median[2]) * 1e6,
    selectr_alloc  = format(html$mem_alloc[1]),
    selectrs_alloc = format(html$mem_alloc[2])))
vectorized$speedup <- vectorized$selectr_us / vectorized$selectrs_us

cat("\n## Vectorized calls\n\n")
cat("| Workload | selectr (µs) | selectrs (µs) | Speedup | selectr alloc | selectrs alloc |\n")
cat("|---|---:|---:|---:|---:|---:|\n")
cat(sprintf("| %s | %s | %s | %.1fx | %s | %s |\n",
            vectorized$workload,
            formatC(vectorized$selectr_us, format = "f", digits = 1, big.mark = ","),
            formatC(vectorized$selectrs_us, format = "f", digits = 1, big.mark = ","),
            vectorized$speedup, vectorized$selectr_alloc,
            vectorized$selectrs_alloc), sep = "")

cat("\n## Environment\n\n")
cat(sprintf("| R | %s |\n", R.version.string))
for (pkg in c("selectr", "selectrs", "bench", "xml2"))
    cat(sprintf("| %s | %s |\n", pkg, packageVersion(pkg)))
