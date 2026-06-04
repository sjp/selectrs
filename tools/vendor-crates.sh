#!/bin/sh
# Regenerate src/rust/vendor.tar.xz — the vendored Rust dependencies shipped
# in the CRAN source tarball so that installation never touches the network
# (src/Makevars extracts it and builds with `cargo build --offline`; the
# crates-io source replacement lives in src/cargo_vendor_config.toml).
#
# Run from the package root before R CMD build:
#   sh tools/vendor-crates.sh
#
# The archive is generated from Cargo.lock (--locked), so the vendored tree
# is exactly the pinned dependency set. Remember to regenerate inst/AUTHORS
# (tools/generate-authors.R) whenever the dependency set changes.
set -e

if [ ! -f DESCRIPTION ] || [ ! -f src/rust/Cargo.lock ]; then
    echo "Run this script from the selectrs package root." >&2
    exit 1
fi

cd src/rust
rm -rf vendor vendor.tar.xz
cargo vendor --locked vendor >/dev/null
# --xz honors XZ_OPT; -9e buys a meaningfully smaller CRAN tarball
XZ_OPT=-9e tar --create --xz --file vendor.tar.xz vendor
rm -rf vendor
ls -lh vendor.tar.xz
