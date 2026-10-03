use magnus::{Error, Ruby};

mod ndarray2d;

// Initializing Rust extension for Ruby
#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    ndarray2d::init(ruby)
}
