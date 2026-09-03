# Benchmarks: selectrs vs selectr

`selectrs` is a Rust-backed port of [`selectr`](https://github.com/sjp/selectr).
This document benchmarks `css_to_xpath()` — the call that performs the actual
CSS-to-XPath translation — in both packages.

## Environment

| Component | Version |
|---|---|
| R | 4.6.1 (2026-06-24) |
| selectr | 0.7-0 (GitHub `master`, 2026-09-03; the CRAN release is 0.6-0) |
| selectrs | 0.0.0.9000, `css-to-xpath` 0.3.0 |
| bench | 1.1.4 |
| xml2 | 1.6.0 |
| Hardware | aarch64, 8 cores (Linux VM on Apple Silicon) |

Run `Rscript tools/benchmark.R` from the package root to reproduce the tables
below. The script needs `selectr` and `bench` installed; neither is in
`Suggests`, because the shipped test suite has to stay self-contained.

## Methodology

- Timings collected with `bench::mark()` (≥200 iterations per expression for
  per-selector runs, ≥20 for the 1,000-selector runs).
- Before any timing, every benchmark selector is translated by both packages
  and both XPath expressions are evaluated against a fixed HTML document that
  every selector matches; the benchmark aborts if they select different nodes.
  The XPath *strings* are deliberately not compared: the two packages agree on
  what a selector selects, not always on how to spell it.
- Both packages cache translations for the duration of a vectorized call, so
  repeated selectors in one vector are translated once. The 1,000-selector
  workload therefore comes in two variants: one repeating the 14 benchmark
  selectors (exercises the cache) and one with 1,000 unique selectors (defeats
  it, measuring raw translation throughput).
- Times reported are medians of a single run; the geometric mean below moved
  by less than 1.5% across repeated runs. `selectr` triggers garbage
  collection in every iteration on the heaviest workload (1,000 unique
  selectors), which is reflected in its timing.

## Per-selector results

One `css_to_xpath()` call per selector, default `"generic"` translator.

| Case | Selector | selectr (µs) | selectrs (µs) | Speedup |
|---|---|---:|---:|---:|
| type | `div` | 198.0 | 8.8 | 22.4x |
| class | `.note` | 306.0 | 9.2 | 33.2x |
| id | `#main` | 285.5 | 8.9 | 32.2x |
| attribute (presence) | `a[rel]` | 533.4 | 9.1 | 58.4x |
| attribute (prefix) | `a[href^='https://']` | 631.6 | 9.4 | 67.4x |
| descendant | `div p` | 574.7 | 9.3 | 61.6x |
| child + class | `div > p.note` | 785.1 | 9.9 | 79.5x |
| compound chain | `ul li a.external` | 949.4 | 9.9 | 95.7x |
| sibling | `h2 ~ p + span` | 938.3 | 9.9 | 95.0x |
| pseudo-class | `p:first-child` | 485.0 | 9.5 | 51.3x |
| nth-child (an+b) | `tr:nth-child(2n+1)` | 776.0 | 9.7 | 80.3x |
| negation | `input:not([type='hidden'])` | 1024.9 | 10.0 | 102.9x |
| union (3 selectors) | `h1, h2, h3` | 849.9 | 9.8 | 86.8x |
| kitchen sink | `div#content > ul.menu li:nth-of-type(2) a[href$='.html']:not(.active)` | 2573.5 | 12.5 | 205.2x |

**Geometric mean speedup: 66.3x.**

Two patterns stand out:

- `selectrs` is essentially flat at **~9–13 µs per call** regardless of
  selector complexity — the time is dominated by the fixed cost of the R→Rust
  call, with the translation itself contributing very little.
- `selectr` scales with selector complexity (parsing and translation happen
  in R), so the speedup grows with complexity: simple type selectors are
  ~22x faster, while the kitchen-sink selector is ~205x faster.

## Vectorized calls

`css_to_xpath()` is vectorized in both packages. `selectrs` makes a single
call into Rust for the whole vector, so the fixed call overhead is amortized:

| Workload | selectr (µs) | selectrs (µs) | Speedup | selectr alloc | selectrs alloc |
|---|---:|---:|---:|---:|---:|
| 14 selectors, one call | 10,938.1 | 28.0 | 390.0x | 1.98KB | 0B |
| 1,000 selectors (14 unique), one call | 13,458.0 | 226.9 | 59.3x | 37.4KB | 43.2KB |
| 1,000 unique selectors, one call | 2,371,937.4 | 3,350.7 | 707.9x | 1.88MB | 238KB |
| `input:checked` (`html` translator) | 506.4 | 9.7 | 52.2x | 1.03KB | 0B |

The repeated-selector workload is dominated by both packages' per-call
translation caches: only the 14 unique selectors are actually translated, so
it mostly measures cache lookup, and both finish in milliseconds. The
unique-selector workload measures raw translation throughput: `selectrs`
finishes in **~3.4 ms vs ~2.4 s** (~708x).

## Compared with selectr 0.6-0

Re-running the same script back to back against the CRAN release (`selectrs`
timings agreed to within 0.2 µs, so the two rounds are comparable):

- 0.7-0 allocates dramatically less R memory — 1.88MB rather than 85.5MB on
  the 1,000-unique-selector call, and 1.98KB rather than 340KB on the
  14-selector call — because it now caches and reuses translator instances.
- Per-call translation time is nevertheless **0–23% higher** than 0.6-0
  across the fourteen selectors, so the speedups above are a little larger
  than they were against 0.6-0 (geometric mean 66.3x against 0.7-0 versus
  58.3x against 0.6-0 on the same machine).

## Takeaways

- For single translations, expect **roughly 22–205x** depending on selector
  complexity; ~66x as a geometric mean over a representative mix.
- For vectorized translation of many distinct selectors, expect
  **~390–710x**. When a vector repeats the same selectors, both packages'
  per-call caches close most of the gap (~59x, with both in the
  milliseconds).
- The two packages select the same nodes for every selector benchmarked, and
  against 0.7-0 all fourteen (plus the `html`-translator case) now produce
  byte-identical XPath. Of the 1,000 generated selectors, 744 still differ,
  but only in whitespace: `selectr` writes `(count(preceding-sibling::*) +3)`
  where `selectrs` writes `+ 3`.
