use magnus::{
    DataTypeFunctions, Error, Float, Integer, IntoValue, RArray, Ruby, TypedData, Value, function,
    method, prelude::*,
};
use ndarray::Array2;

// Elements are kept in the narrowest Rust type able to represent all of them
// exactly, so Ruby semantics (Integer vs Float) are preserved.
enum Storage {
    Int(Array2<i64>),
    Float(Array2<f64>),
}

impl Storage {
    fn from_values(ruby: &Ruby, shape: (usize, usize), values: Vec<Value>) -> Result<Self, Error> {
        let ints: Option<Vec<i64>> = values
            .iter()
            .map(|&v| Integer::from_value(v).and_then(|i| i.to_i64().ok()))
            .collect();
        if let Some(ints) = ints {
            return Ok(Self::Int(build_array(shape, ints)));
        }

        let floats: Option<Vec<f64>> = values
            .iter()
            .map(|&v| Float::from_value(v).map(|f| f.to_f64()))
            .collect();
        if let Some(floats) = floats {
            return Ok(Self::Float(build_array(shape, floats)));
        }

        Err(Error::new(
            ruby.exception_type_error(),
            "NDArray::Matrix only supports Integer (fitting in 64 bits) or Float elements",
        ))
    }

    fn dim(&self) -> (usize, usize) {
        match self {
            Self::Int(a) => a.dim(),
            Self::Float(a) => a.dim(),
        }
    }
}

fn build_array<T>(shape: (usize, usize), values: Vec<T>) -> Array2<T> {
    Array2::from_shape_vec(shape, values).expect("element count must match the shape")
}

fn rows_to_ruby<T: IntoValue + Copy>(ruby: &Ruby, array: &Array2<T>) -> Result<RArray, Error> {
    let rows = ruby.ary_new_capa(array.nrows());
    for row in array.outer_iter() {
        rows.push(ruby.ary_from_iter(row.iter().copied()))?;
    }
    Ok(rows)
}

#[derive(TypedData)]
#[magnus(class = "NDArray::Matrix", free_immediately)]
pub struct Matrix {
    storage: Storage,
}

impl DataTypeFunctions for Matrix {}

impl Matrix {
    // Matrix[*rows]
    fn from_rows(ruby: &Ruby, rows: &[Value]) -> Result<Self, Error> {
        let rows = rows
            .iter()
            .map(|&row| RArray::try_convert(row))
            .collect::<Result<Vec<_>, _>>()?;
        let row_count = rows.len();
        let column_count = rows.first().map_or(0, |row| row.len());

        let mut values = Vec::with_capacity(row_count * column_count);
        for row in &rows {
            if row.len() != column_count {
                // TODO: raise Matrix::ErrDimensionMismatch once the exceptions exist.
                return Err(Error::new(
                    ruby.exception_arg_error(),
                    format!("row size differs ({} should be {})", row.len(), column_count),
                ));
            }
            values.extend(*row);
        }

        let storage = Storage::from_values(ruby, (row_count, column_count), values)?;
        Ok(Self { storage })
    }

    fn row_count(&self) -> usize {
        self.storage.dim().0
    }

    fn column_count(&self) -> usize {
        self.storage.dim().1
    }

    fn to_a(ruby: &Ruby, rb_self: &Self) -> Result<RArray, Error> {
        match &rb_self.storage {
            Storage::Int(a) => rows_to_ruby(ruby, a),
            Storage::Float(a) => rows_to_ruby(ruby, a),
        }
    }
}

// Define the Ruby `NDArray::Matrix` class, mirroring the stdlib `Matrix` API
pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let namespace = ruby.define_class("NDArray", ruby.class_object())?;
    let class = namespace.define_class("Matrix", ruby.class_object())?;

    class.define_singleton_method("[]", function!(Matrix::from_rows, -1))?;

    class.define_method("row_count", method!(Matrix::row_count, 0))?;
    class.define_alias("row_size", "row_count")?;
    class.define_method("column_count", method!(Matrix::column_count, 0))?;
    class.define_alias("column_size", "column_count")?;
    class.define_method("to_a", method!(Matrix::to_a, 0))?;
    Ok(())
}
