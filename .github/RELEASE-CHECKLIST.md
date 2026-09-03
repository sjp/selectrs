# Release checklist

Maintainer notes; not shipped in the tarball. Items CI already enforces
on every push are marked *(CI)* — they are listed so the reason for the
step is in one place, not because they need doing by hand.

## After a dependency bump (Dependabot, or `cargo update`)

- [ ] Re-run `tools/vendor-crates.sh` so `src/rust/vendor.tar.xz` holds
      exactly what `src/rust/Cargo.lock` pins; the CRAN build path is
      `--offline --locked` against that archive.
- [ ] Re-run `Rscript tools/generate-authors.R` *(CI)*.
- [ ] Check whether the resolved tree raises the minimum Rust version.
      The floor is the newest `rust-version` in it, and four files state
      it: `src/rust/Cargo.toml`, `configure`, `configure.win`, and
      `SystemRequirements` in `DESCRIPTION` *(CI checks the four agree,
      not that they match the tree)*.
- [ ] Add any licence that is not MIT or Apache-2.0 to `LICENSE.note`.

## Before a release

- [ ] Bump `Version` in `DESCRIPTION` and `version` in both
      `src/rust/Cargo.toml` and `src/rust/Cargo.lock` *(CI checks
      DESCRIPTION against Cargo.toml)*.
- [ ] Write the `NEWS.md` section.
- [ ] Run `R CMD check --as-cran` on the built tarball and read the
      `installed size` line. It sits at about 6.1Mb, nearly all of it
      DWARF that the prebuilt Rust standard library contributes at link
      time — `cran-comments.md` explains this to the reviewer. A jump
      well beyond that is something else growing, a dependency embedding
      a large table say, and wants investigating rather than
      re-justifying.
- [ ] Refresh the check results and the size figures in
      `cran-comments.md`.
- [ ] Re-measure `BENCHMARKS.md` if the Rust core changed.
