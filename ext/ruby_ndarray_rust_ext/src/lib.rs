use magnus::{function, method, prelude::*, Error, Ruby};
use ndarray::Array2;

#[magnus::wrap(class = "NDArray")]
struct NDArray {
    data: Array2<f64>,
}

impl NDArray {
    fn from_array(ruby: &Ruby, array: Vec<Vec<f64>>) -> Result<Self, Error> {
        let rows = array.len();
        let cols = array.first().map_or(0, |row| row.len());

        // Flatten the Vec<Vec<f64>> into a single Vec<f64>
        let flattened: Vec<f64> = array.into_iter().flatten().collect();

        // Create a 2D ndarray
        let ndarray = Array2::from_shape_vec((rows, cols), flattened)
            .map_err(|e| Error::new(ruby.exception_arg_error(), e.to_string()))?;

        Ok(Self { data: ndarray })
    }

    fn dot(ruby: &Ruby, rb_self: &Self, other: &NDArray) -> Result<Self, Error> {
        // Check if the dimensions are compatible for the dot product
        if rb_self.data.ncols() != other.data.nrows() {
            return Err(Error::new(
                ruby.exception_arg_error(),
                "Incompatible dimensions for dot product: number of columns in the first matrix must equal the number of rows in the second matrix",
            ));
        }
        let result = rb_self.data.dot(&other.data);
        Ok(Self { data: result })
    }

    fn to_a(_ruby: &Ruby, rb_self: &Self) -> Vec<Vec<f64>> {
        // Iterate over the rows and collect each row into a Vec<f64>
        rb_self.data.outer_iter().map(|row| row.to_vec()).collect()
    }
}

// Initializing Rust extension for Ruby
#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    // Define the Ruby `NDArray` class
    let class = ruby.define_class("NDArray", ruby.class_object())?;

    // Define the `from_array` class method that creates a new `NDArray` instance
    class.define_singleton_method("from_array", function!(NDArray::from_array, 1))?;

    // Define the `dot` instance method
    class.define_method("dot", method!(NDArray::dot, 1))?;

    // Define the `to_a` instance method that returns the 2D array as a Vec<Vec<f64>>
    class.define_method("to_a", method!(NDArray::to_a, 0))?;
    Ok(())
}
