PKG_VERSION = $(shell grep -i ^version DESCRIPTION | cut -d : -d \  -f 2)
PKG_NAME = $(shell grep -i ^package DESCRIPTION | cut -d : -d \  -f 2)

INST_FILES := $(shell find inst -type f -print)
MAN_FILES := $(wildcard man/*.Rd)
R_FILES := $(wildcard R/*.R)
RUST_FILES := $(shell find src/rust/src -name '*.rs')
TEST_FILES := $(shell find tests -name '*.R')
PKG_FILES := DESCRIPTION NAMESPACE $(TEST_FILES) $(R_FILES) $(MAN_FILES) \
             $(INST_FILES) $(RUST_FILES) src/rust/Cargo.toml src/rust/Cargo.lock

# The CRAN tarball carries the crate sources it builds from, so vendoring
# comes before every R CMD build.
VENDOR = src/rust/vendor.tar.xz

# savvy's build script compiles a C shim against the R headers, so every
# cargo invocation that builds the crate needs these.
R_INCLUDE_DIR = $(shell Rscript -e 'cat(normalizePath(R.home("include")))')
CARGO = cd src/rust && R_INCLUDE_DIR=$(R_INCLUDE_DIR) cargo

.PHONY: build check test lint install run vendor fmt clippy cargo-test clean

build: $(PKG_NAME)_$(PKG_VERSION).tar.gz

vendor: $(VENDOR)

$(VENDOR): src/rust/Cargo.lock src/rust/Cargo.toml
	tools/vendor-crates.sh

$(PKG_NAME)_$(PKG_VERSION).tar.gz: $(PKG_FILES) $(VENDOR)
	R CMD build ./

check: $(PKG_NAME)_$(PKG_VERSION).tar.gz
	R CMD check --as-cran $<

test:
	Rscript -e 'testthat::test_local()'

lint:
	Rscript -e 'lintr::lint_package()'

fmt:
	cd src/rust && cargo fmt --check

clippy:
	$(CARGO) clippy --locked --all-targets -- -D warnings

cargo-test:
	$(CARGO) test --locked

install: $(PKG_NAME)_$(PKG_VERSION).tar.gz
	R CMD INSTALL $<

run: $(PKG_NAME)_$(PKG_VERSION).tar.gz
	R CMD INSTALL $<
	R

clean:
	-rm $(PKG_NAME)*.tar.gz
	-rm -rf $(PKG_NAME).Rcheck
	-rm -rf src/rust/target $(VENDOR)
