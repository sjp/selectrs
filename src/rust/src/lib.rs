use savvy::savvy;
use savvy::OwnedStringSexp;

/// Version of the selectrs Rust core
///
/// Returns the version of the underlying Rust crate. A trivial export used
/// to verify that the Rust toolchain and FFI bindings are working.
///
/// @returns A length-one character vector.
/// @noRd
#[savvy]
fn selectrs_core_version() -> savvy::Result<savvy::Sexp> {
    let mut out = OwnedStringSexp::new(1)?;
    out.set_elt(0, env!("CARGO_PKG_VERSION"))?;
    Ok(out.into())
}

#[cfg(test)]
mod tests {
    #[test]
    fn version_matches_manifest() {
        assert_eq!(env!("CARGO_PKG_VERSION"), "0.1.0");
    }
}
