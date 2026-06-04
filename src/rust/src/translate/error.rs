//! Error types for selector translation.
//!
//! Errors always name the selector and the construct. The exact wording
//! here is pinned by snapshot tests on the R side.

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Error {
    /// The selector is not valid CSS (as judged by Servo's parser).
    Parse(String),
    /// The selector is valid CSS, but uses a construct outside the
    /// supported set: selectrs errors rather than approximating.
    Unsupported(String),
}

impl Error {
    /// Render the user-facing message, naming the offending selector.
    pub fn into_message(self, selector: &str) -> String {
        match self {
            Error::Parse(detail) => {
                format!("Unable to parse the CSS selector {selector:?}: {detail}")
            },
            Error::Unsupported(construct) => format!(
                "The CSS selector {selector:?} uses {construct}, which selectrs does not support"
            ),
        }
    }
}
