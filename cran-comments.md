## Submission

This is a new submission.

## Test environments

* local aarch64 Linux (Debian), R 4.6.1, rustc 1.97.1
* GitHub Actions: ubuntu-latest (r-devel, release, oldrel-1),
  macos-latest (release), windows-latest (release)

## R CMD check results

0 errors | 0 warnings | 2 notes

* New submission.

* Installed package size:

      installed size is  6.1Mb
      sub-directories of 1Mb or more:
        libs   6.0Mb

  `libs/` is the statically linked Rust core. Only 1.5Mb of it is
  machine code (`size` reports 1,515,417 bytes of `.text`); the rest is
  DWARF debug information contributed at link time by the prebuilt Rust
  standard library, whose compilation units point at
  `/rustc/<hash>/library/...` rather than at this package. Cargo's
  `strip` and `debug` profile settings do not reach it, because the
  staticlib is linked by R's toolchain rather than by cargo.
  `strip --strip-debug` takes the shared object to 2.2Mb, so
  `R CMD INSTALL --strip`, which the CRAN binary builders use, keeps the
  installed binaries well under the threshold.

## Rust

The parsing and translation core is written in Rust, following the CRAN
policy for such packages:

* `SystemRequirements` declares Cargo and `rustc (>= 1.88)`. `configure`
  and `configure.win` report the cargo and rustc versions into the
  install log and stop with an actionable message when rustc is older
  than that.

* All crate dependencies are vendored in the tarball as
  `src/rust/vendor.tar.xz`. The build extracts them, redirects
  `CARGO_HOME` to a throwaway directory under the build directory, and
  runs `cargo build --offline --locked`, so it writes nothing to the
  user's home and makes no network access. Both directories are removed
  when the build finishes.

* Cargo is limited to two parallel jobs, as the policy requires.

* On Windows the Rust target and linker are chosen from the
  architecture R reports: `x86_64-pc-windows-gnu` with the MinGW-w64
  GCC that Rtools provides, which is the path CRAN's three Windows
  flavours take, and `aarch64-pc-windows-gnullvm` with Rtools' clang
  otherwise. The aarch64 branch is there for users building from source
  under the experimental ARM64 Rtools; it is untested, as no CRAN
  flavour, win-builder machine or CI runner covers that platform.

* The crate authors are credited as copyright holders in `Authors@R`.
  `inst/AUTHORS` lists every vendored crate with its version, licence,
  authors and repository, and `LICENSE.note` summarises the licences
  that differ from the package's own (four crates are MPL-2.0, whose
  sources the vendored archive provides).
