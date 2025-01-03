use magnus::{function, prelude::*, Error, Ruby};

fn hello(subject: String) -> String {
    format!("Hello from Rust, {subject}!")
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let ndarray_rb_class = ruby.define_class("NDArray", ruby.class_object())?;
    ndarray_rb_class.define_singleton_method("hello", function!(hello, 1))?;
    Ok(())
}
