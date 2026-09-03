#!/usr/bin/env Rscript
# Regenerate inst/AUTHORS: the attribution chain for the ported R code and
# tests, plus the authors/licenses of every vendored Rust crate (from
# `cargo metadata`, i.e. the same pinned tree that tools/vendor-crates.sh
# archives into src/rust/vendor.tar.xz).
#
# Run from the package root:  Rscript tools/generate-authors.R

if (!file.exists("DESCRIPTION") || !file.exists("src/rust/Cargo.lock"))
    stop("Run this script from the selectrs package root.")

md <- jsonlite::fromJSON(system2(
    "cargo",
    c("metadata", "--format-version", "1", "--locked",
      "--manifest-path", "src/rust/Cargo.toml"),
    stdout = TRUE), simplifyDataFrame = FALSE)

pkgs <- Filter(function(p) p$name != "selectrs", md$packages)
pkgs <- pkgs[order(vapply(pkgs, `[[`, character(1), "name"))]

crate_block <- vapply(pkgs, function(p) {
    authors <- unlist(p$authors)
    authors <- if (length(authors)) paste(authors, collapse = ", ")
               else "(not stated; see repository)"
    repo <- if (is.null(p$repository)) "(no repository listed)" else p$repository
    sprintf("%s %s\n  License: %s\n  Authors: %s\n  Repository: %s",
            p$name, p$version, p$license, authors, repo)
}, character(1))

header <- c(
    "Authors and copyright holders of code bundled with or ported into selectrs",
    "===========================================================================",
    "",
    "R code and tests",
    "----------------",
    "",
    "The R sources (R/) and the test suites (tests/testthat/) are ports of the",
    "'selectr' package by Simon Potter (https://github.com/sjp/selectr,",
    "BSD 3-clause). selectr is itself a translation of the Python package",
    "'cssselect' (https://github.com/scrapy/cssselect, BSD 3-clause) by",
    "Ian Bicking, Simon Sapin, and contributors, originally part of",
    "lxml.cssselect.",
    "Copyright holders of the ported code: Simon Potter, Simon Sapin,",
    "Ian Bicking.",
    "",
    "Vendored Rust crates",
    "--------------------",
    "",
    "The Rust core statically links the following crates, vendored in the",
    "source tarball as src/rust/vendor.tar.xz (versions exactly as pinned in",
    "src/rust/Cargo.lock). Their licenses and authors, from `cargo metadata`:",
    "")

writeLines(c(header, paste(crate_block, collapse = "\n\n")), "inst/AUTHORS")
message("wrote inst/AUTHORS (", length(pkgs), " crates)")
