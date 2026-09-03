//! Makes the resolved `css-to-xpath` version available to the crate.
//!
//! The crate exports no version constant, and cargo gives a crate no way
//! to read a dependency's version from its own source, so it is taken
//! from the lock file — the version actually resolved, rather than the
//! requirement the manifest states — and handed to `env!`.

use std::{env, fs, path::Path};

// Shared with the crate's test target, which is where its tests are:
// cargo runs none in a build script.
#[path = "src/locked_version.rs"]
mod locked_version;
use locked_version::locked_version;

fn main() {
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").expect("cargo sets CARGO_MANIFEST_DIR");
    let lock_path = Path::new(&manifest_dir).join("Cargo.lock");
    println!("cargo::rerun-if-changed={}", lock_path.display());

    let lock = fs::read_to_string(&lock_path)
        .unwrap_or_else(|error| panic!("cannot read {}: {error}", lock_path.display()));
    let version = locked_version(&lock, "css-to-xpath")
        .unwrap_or_else(|| panic!("no css-to-xpath package in {}", lock_path.display()));
    println!("cargo::rustc-env=CSS_TO_XPATH_VERSION={version}");
}
