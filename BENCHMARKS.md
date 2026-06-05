# Benchmarks: selectrs vs selectr

`selectrs` is a Rust-backed port of [`selectr`](https://github.com/sjp/selectr).
This document benchmarks `css_to_xpath()` — the call that performs the actual
CSS-to-XPath translation — in both packages.

## Environment

| Component | Version |
|---|---|
| R | 4.6.0 (2026-04-24) |
| selectr | 0.6.0 (GitHub `master` @ `c270f00`, 2026-06-05) |
| selectrs | 0.0.0.9000 (working tree @ `350ef2b`) |
| bench | 1.1.4 |
| Hardware | aarch64, 8 cores (Linux VM on Apple Silicon) |

## Methodology

- Timings collected with `bench::mark()` (≥200 iterations per expression for
  per-selector runs, ≥20 for the 1,000-selector runs).
- Before any timing, every benchmark selector is translated by both packages
  and the outputs checked with `identical()` — the benchmark aborts on any
  mismatch. `bench::mark(check = TRUE)` additionally verifies equality on
  every timed expression pair.
- Both packages now cache translations for the duration of a vectorized
  call, so repeated selectors in one vector are translated once. The
  1,000-selector workload therefore comes in two variants: one repeating the
  14 benchmark selectors (exercises the cache) and one with 1,000 unique
  selectors (defeats it, measuring raw translation throughput).
- Times reported are medians. `selectr` triggers garbage collection in every
  iteration on the heaviest workload (1,000 unique selectors), which is
  reflected in its timing.
- The full benchmark script is in the appendix.

## Per-selector results

One `css_to_xpath()` call per selector, default `"generic"` translator.

| Case | Selector | selectr (µs) | selectrs (µs) | Speedup |
|---|---|---:|---:|---:|
| type | `div` | 174.5 | 10.1 | 17.2x |
| class | `.note` | 248.4 | 10.8 | 23.1x |
| id | `#main` | 228.3 | 10.5 | 21.7x |
| attribute (presence) | `a[rel]` | 520.8 | 10.8 | 48.3x |
| attribute (prefix) | `a[href^='https://']` | 635.1 | 10.8 | 58.6x |
| descendant | `div p` | 510.3 | 10.8 | 47.1x |
| child + class | `div > p.note` | 699.0 | 11.3 | 62.1x |
| compound chain | `ul li a.external` | 822.9 | 11.5 | 71.3x |
| sibling | `h2 ~ p + span` | 815.1 | 11.2 | 72.5x |
| pseudo-class | `p:first-child` | 460.8 | 10.8 | 42.5x |
| nth-child (an+b) | `tr:nth-child(2n+1)` | 701.1 | 10.8 | 65.2x |
| negation | `input:not([type='hidden'])` | 906.1 | 11.2 | 81.1x |
| union (3 selectors) | `h1, h2, h3` | 726.0 | 10.9 | 66.5x |
| kitchen sink | `div#content > ul.menu li:nth-of-type(2) a[href$='.html']:not(.active)` | 2098.3 | 13.7 | 153.1x |

**Geometric mean speedup: 51.2x.**

Two patterns stand out:

- `selectrs` is essentially flat at **~10–14 µs per call** regardless of
  selector complexity — the time is dominated by the fixed cost of the R→Rust
  call, with the translation itself contributing very little.
- `selectr` scales with selector complexity (parsing and translation happen
  in R), so the speedup grows with complexity: simple type selectors are
  ~17x faster, while the kitchen-sink selector is ~153x faster.

Compared with the previous round of this benchmark (selectr @ `918f3b1`,
selectrs @ `df7c88e`), `selectr` itself got **~1.5–2.2x faster** on all but
the simplest selectors (tokenizer rewrite, dropped stringr dependency,
regex and dispatch improvements), which is why the speedup factors shrank
even though `selectrs` timings are unchanged.

## Vectorized calls

`css_to_xpath()` is vectorized in both packages. `selectrs` makes a single
call into Rust for the whole vector, so the fixed call overhead is amortized:

| Workload | selectr (µs) | selectrs (µs) | Speedup | selectr alloc | selectrs alloc |
|---|---:|---:|---:|---:|---:|
| 14 selectors, one call | 9,392.1 | 27.8 | 337.4x | 346KB | 0B |
| 1,000 selectors (14 unique), one call | 11,704.3 | 202.4 | 57.8x | 378KB | 39.3KB |
| 1,000 unique selectors, one call | 1,965,715.4 | 3,069.9 | 640.3x | 84.8MB | 39.3KB |
| `input:checked` (`html` translator) | 512.5 | 10.6 | 48.2x | 40.1KB | 0B |

The repeated-selector workload is dominated by both packages' per-call
translation caches: only the 14 unique selectors are actually translated, so
it mostly measures cache lookup (and both finish in milliseconds —
`selectr` took ~1.16 s on this workload before it cached). The
unique-selector workload measures raw translation throughput: `selectrs`
finishes in **~3.1 ms vs ~1.97 s** (~640x) and allocates ~39KB of R memory
vs ~85MB — `selectr`'s per-selector R allocations are what force a GC in
every iteration there.

## Takeaways

- For single translations, expect **roughly 17–150x** depending on selector
  complexity; ~51x as a geometric mean over a representative mix.
- For vectorized translation of many distinct selectors, expect
  **~340–640x**. When a vector repeats the same selectors, both packages'
  per-call caches close most of the gap (~58x, with both in the
  milliseconds).
- Both packages produce byte-identical XPath for every selector benchmarked.

## Reproducing

Run the script below with both packages installed
(`Rscript benchmark.R`). It aborts if the two packages ever disagree on a
translation.

```r
library(bench)

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

# Correctness gate: outputs must be identical before timing anything
for (s in selectors) {
    a <- selectr::css_to_xpath(s)
    b <- selectrs::css_to_xpath(s)
    if (!identical(a, b))
        stop(sprintf("Mismatch for %s\n  selectr:  %s\n  selectrs: %s", s, a, b))
}
stopifnot(identical(selectr::css_to_xpath("input:checked", translator = "html"),
                    selectrs::css_to_xpath("input:checked", translator = "html")))

# Per-selector
per_sel <- lapply(seq_along(selectors), function(i) {
    s <- selectors[[i]]
    res <- bench::mark(
        selectr  = selectr::css_to_xpath(s),
        selectrs = selectrs::css_to_xpath(s),
        min_iterations = 200,
        check = TRUE
    )
    data.frame(case = names(selectors)[i],
               selectr_us  = as.numeric(res$median[1]) * 1e6,
               selectrs_us = as.numeric(res$median[2]) * 1e6,
               speedup = as.numeric(res$median[1]) / as.numeric(res$median[2]))
})
per_sel <- do.call(rbind, per_sel)
print(per_sel)
cat(sprintf("Geometric mean speedup: %.1fx\n", exp(mean(log(per_sel$speedup)))))

# Vectorized: all selectors in one call
print(bench::mark(
    selectr  = selectr::css_to_xpath(unname(selectors)),
    selectrs = selectrs::css_to_xpath(unname(selectors)),
    min_iterations = 200, check = TRUE))

# Throughput: 1,000-element selector vector with 14 unique selectors —
# exercises both packages' per-call translation caches
big <- rep(unname(selectors), length.out = 1000)
print(bench::mark(
    selectr  = selectr::css_to_xpath(big),
    selectrs = selectrs::css_to_xpath(big),
    min_iterations = 20, check = TRUE))

# Throughput: 1,000 unique selectors — defeats the caches, measuring raw
# translation throughput
uniq <- sprintf("div#id%d > ul.menu%d li:nth-child(%dn+%d) a[href^='/p%d']",
                1:1000, 1:1000, 1:1000 %% 7 + 2, 1:1000 %% 5, 1:1000)
stopifnot(identical(selectr::css_to_xpath(uniq), selectrs::css_to_xpath(uniq)))
print(bench::mark(
    selectr  = selectr::css_to_xpath(uniq),
    selectrs = selectrs::css_to_xpath(uniq),
    min_iterations = 20, check = TRUE))

# html translator
print(bench::mark(
    selectr  = selectr::css_to_xpath("input:checked", translator = "html"),
    selectrs = selectrs::css_to_xpath("input:checked", translator = "html"),
    min_iterations = 200, check = TRUE))
```
