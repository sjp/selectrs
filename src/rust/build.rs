//! Makes the resolved `css-to-xpath` version available to the crate.
//!
//! The crate exports no version constant, and cargo gives a crate no way
//! to read a dependency's version from its own source, so it is taken
//! from the lock file — the version actually resolved, rather than the
//! requirement the manifest states — and handed to `env!`.

use std::{env, fs, path::Path};

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

/// The `version` of the `[[package]]` stanza naming `crate_name`.
fn locked_version<'a>(lock: &'a str, crate_name: &str) -> Option<&'a str> {
    let name = format!("name = \"{crate_name}\"");
    let mut named = false;
    for line in lock.lines().map(str::trim) {
        if line == "[[package]]" {
            named = false;
        } else if line == name {
            named = true;
        } else if named
            && let Some(version) = line
                .strip_prefix("version = \"")
                .and_then(|rest| rest.strip_suffix('"'))
        {
            return Some(version);
        }
    }
    None
}
