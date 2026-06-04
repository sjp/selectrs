# Benchmarks: selectrs vs selectr

`selectrs` is a Rust-backed port of [`selectr`](https://github.com/sjp/selectr).
This document benchmarks `css_to_xpath()` — the call that performs the actual
CSS-to-XPath translation — in both packages.

## Environment

| Component | Version |
|---|---|
| R | 4.6.0 (2026-04-24) |
| selectr | 0.6.0 (GitHub `master` @ `918f3b1`, 2026-06-04) |
| selectrs | 0.0.0.9000 (working tree @ `df7c88e`) |
| bench | 1.1.4 |
| Hardware | aarch64, 8 cores (Linux VM on Apple Silicon) |

## Methodology

- Timings collected with `bench::mark()` (≥200 iterations per expression for
  per-selector runs, ≥20 for the 1,000-selector run).
- Before any timing, every benchmark selector is translated by both packages
  and the outputs checked with `identical()` — the benchmark aborts on any
  mismatch. `bench::mark(check = TRUE)` additionally verifies equality on
  every timed expression pair.
- Times reported are medians. `selectr` triggers garbage collection in every
  iteration on most of these workloads, which is reflected in its timings.
- The full benchmark script is in the appendix.

## Per-selector results

One `css_to_xpath()` call per selector, default `"generic"` translator.

| Case | Selector | selectr (µs) | selectrs (µs) | Speedup |
|---|---|---:|---:|---:|
| type | `div` | 164.1 | 10.2 | 16.1x |
| class | `.note` | 551.5 | 10.6 | 52.1x |
| id | `#main` | 210.1 | 10.6 | 19.8x |
| attribute (presence) | `a[rel]` | 786.7 | 10.7 | 73.5x |
| attribute (prefix) | `a[href^='https://']` | 1045.2 | 11.2 | 93.3x |
| descendant | `div p` | 688.1 | 10.6 | 64.8x |
| child + class | `div > p.note` | 1084.8 | 11.1 | 97.5x |
| compound chain | `ul li a.external` | 1203.8 | 11.5 | 105.1x |
| sibling | `h2 ~ p + span` | 1257.8 | 11.4 | 110.2x |
| pseudo-class | `p:first-child` | 688.6 | 10.9 | 63.3x |
| nth-child (an+b) | `tr:nth-child(2n+1)` | 1305.0 | 11.0 | 118.2x |
| negation | `input:not([type='hidden'])` | 1587.9 | 11.2 | 141.2x |
| union (3 selectors) | `h1, h2, h3` | 1117.7 | 10.9 | 102.4x |
| kitchen sink | `div#content > ul.menu li:nth-of-type(2) a[href$='.html']:not(.active)` | 3820.2 | 14.1 | 270.5x |

**Geometric mean speedup: 76.7x.**

Two patterns stand out:

- `selectrs` is essentially flat at **~10–14 µs per call** regardless of
  selector complexity — the time is dominated by the fixed cost of the R→Rust
  call, with the translation itself contributing very little.
- `selectr` scales with selector complexity (parsing and translation happen
  in R), so the speedup grows with complexity: simple type selectors are
  ~16x faster, while the kitchen-sink selector is ~270x faster.

## Vectorized calls

`css_to_xpath()` is vectorized in both packages. `selectrs` makes a single
call into Rust for the whole vector, so the fixed call overhead is amortized:

| Workload | selectr (µs) | selectrs (µs) | Speedup | selectr alloc | selectrs alloc |
|---|---:|---:|---:|---:|---:|
| 14 selectors, one call | 15,545.0 | 26.7 | 582.9x | 789KB | 0B |
| 1,000 selectors, one call | 1,161,133.6 | 1,164.9 | 996.8x | 54.4MB | 39.3KB |
| `input:checked` (`html` translator) | 765.0 | 10.5 | 72.9x | 40.1KB | 0B |

On the 1,000-selector workload `selectrs` finishes in **~1.2 ms vs ~1.16 s**
(~1,000x) and allocates ~39KB of R memory vs ~54MB — `selectr`'s per-call R
allocations are what force a GC in nearly every iteration.

## Takeaways

- For single translations, expect **roughly 15–270x** depending on selector
  complexity; ~77x as a geometric mean over a representative mix.
- For vectorized translation of many selectors, expect **~500–1,000x**.
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

# Throughput: 1,000-element selector vector
big <- rep(unname(selectors), length.out = 1000)
print(bench::mark(
    selectr  = selectr::css_to_xpath(big),
    selectrs = selectrs::css_to_xpath(big),
    min_iterations = 20, check = TRUE))

# html translator
print(bench::mark(
    selectr  = selectr::css_to_xpath("input:checked", translator = "html"),
    selectrs = selectrs::css_to_xpath("input:checked", translator = "html"),
    min_iterations = 200, check = TRUE))
```
