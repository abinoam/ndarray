use std::cell::RefCell;

use magnus::{
    DataTypeFunctions, Error, Float, Integer, IntoValue, RArray, Ruby, TypedData, Value, function,
    gc, method, prelude::*, scan_args::scan_args, value::Opaque,
};
use ndarray::Array2;

// Elements are kept in the narrowest Rust type able to represent all of them
// exactly, so Ruby semantics (Integer vs Float) are preserved. Anything else
// (Rational, Complex, Bignum, mixed types...) falls back to Ruby objects.
#[derive(Clone)]
enum Storage {
    Int(Array2<i64>),
    Float(Array2<f64>),
    Object(Array2<Opaque<Value>>),
}

impl Storage {
    fn from_values(shape: (usize, usize), values: Vec<Value>) -> Self {
        let ints: Option<Vec<i64>> = values
            .iter()
            .map(|&v| Integer::from_value(v).and_then(|i| i.to_i64().ok()))
            .collect();
        if let Some(ints) = ints {
            return Self::Int(build_array(shape, ints));
        }

        let floats: Option<Vec<f64>> = values
            .iter()
            .map(|&v| Float::from_value(v).map(|f| f.to_f64()))
            .collect();
        if let Some(floats) = floats {
            return Self::Float(build_array(shape, floats));
        }

        let objects = values.into_iter().map(Opaque::from).collect();
        Self::Object(build_array(shape, objects))
    }

    fn get(&self, ruby: &Ruby, index: (usize, usize)) -> Value {
        match self {
            Self::Int(a) => a[index].into_value_with(ruby),
            Self::Float(a) => a[index].into_value_with(ruby),
            Self::Object(a) => ruby.get_inner(a[index]),
        }
    }

    fn dim(&self) -> (usize, usize) {
        match self {
            Self::Int(a) => a.dim(),
            Self::Float(a) => a.dim(),
            Self::Object(a) => a.dim(),
        }
    }
}

fn build_array<T>(shape: (usize, usize), values: Vec<T>) -> Array2<T> {
    Array2::from_shape_vec(shape, values).expect("element count must match the shape")
}

// Resolves a Ruby index (negative counts from the end) into 0...len
fn resolve_index(index: i64, len: usize) -> Option<usize> {
    let len = i64::try_from(len).ok()?;
    let index = if index < 0 { index + len } else { index };
    (0..len).contains(&index).then_some(index as usize)
}

fn rows_to_ruby<T: IntoValue + Copy>(ruby: &Ruby, array: &Array2<T>) -> Result<RArray, Error> {
    let rows = ruby.ary_new_capa(array.nrows());
    for row in array.outer_iter() {
        rows.push(ruby.ary_from_iter(row.iter().copied()))?;
    }
    Ok(rows)
}

impl Default for Storage {
    fn default() -> Self {
        Self::Int(Array2::zeros((0, 0)))
    }
}

// The storage sits in a RefCell because Ruby allocates objects before
// initializing them (e.g. #clone and #dup call #initialize_copy).
#[derive(Default, TypedData)]
#[magnus(class = "NDArray::Matrix", free_immediately, mark)]
pub struct Matrix {
    storage: RefCell<Storage>,
}

impl Matrix {
    fn new(storage: Storage) -> Self {
        Self {
            storage: RefCell::new(storage),
        }
    }
}

impl DataTypeFunctions for Matrix {
    // Keep the Ruby objects held by the Object storage alive.
    fn mark(&self, marker: &gc::Marker) {
        if let Storage::Object(a) = &*self.storage.borrow() {
            a.iter().for_each(|&value| marker.mark(value));
        }
    }
}

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

        let storage = Storage::from_values((row_count, column_count), values);
        Ok(Self::new(storage))
    }

    // Matrix.empty(row_count = 0, column_count = 0)
    fn empty(ruby: &Ruby, args: &[Value]) -> Result<Self, Error> {
        let args = scan_args::<(), (Option<i64>, Option<i64>), (), (), (), ()>(args)?;
        let (row_count, column_count) = args.optional;
        let (row_count, column_count) = (row_count.unwrap_or(0), column_count.unwrap_or(0));

        if row_count != 0 && column_count != 0 {
            return Err(Error::new(ruby.exception_arg_error(), "One size must be 0"));
        }
        if row_count < 0 || column_count < 0 {
            return Err(Error::new(ruby.exception_arg_error(), "Negative size"));
        }

        let shape = (row_count as usize, column_count as usize);
        Ok(Self::new(Storage::Int(build_array(shape, Vec::new()))))
    }

    // matrix[i, j]: the element at row i, column j, or nil when out of range
    fn element(ruby: &Ruby, rb_self: &Self, i: i64, j: i64) -> Option<Value> {
        let storage = rb_self.storage.borrow();
        let (row_count, column_count) = storage.dim();
        let index = (resolve_index(i, row_count)?, resolve_index(j, column_count)?);
        Some(storage.get(ruby, index))
    }

    fn row_count(&self) -> usize {
        self.storage.borrow().dim().0
    }

    fn column_count(&self) -> usize {
        self.storage.borrow().dim().1
    }

    // Called by #clone and #dup on a freshly allocated copy
    fn initialize_copy(&self, original: &Self) {
        let storage = original.storage.borrow().clone();
        *self.storage.borrow_mut() = storage;
    }

    fn to_a(ruby: &Ruby, rb_self: &Self) -> Result<RArray, Error> {
        match &*rb_self.storage.borrow() {
            Storage::Int(a) => rows_to_ruby(ruby, a),
            Storage::Float(a) => rows_to_ruby(ruby, a),
            Storage::Object(a) => rows_to_ruby(ruby, a),
        }
    }
}

// Define the Ruby `NDArray::Matrix` class, mirroring the stdlib `Matrix` API
pub fn init(ruby: &Ruby) -> Result<(), Error> {
    let namespace = ruby.define_class("NDArray", ruby.class_object())?;
    let class = namespace.define_class("Matrix", ruby.class_object())?;
    class.define_alloc_func::<Matrix>();

    class.define_singleton_method("[]", function!(Matrix::from_rows, -1))?;
    class.define_singleton_method("empty", function!(Matrix::empty, -1))?;

    class.define_method("[]", method!(Matrix::element, 2))?;
    class.define_alias("element", "[]")?;
    class.define_alias("component", "[]")?;
    class.define_method("row_count", method!(Matrix::row_count, 0))?;
    class.define_alias("row_size", "row_count")?;
    class.define_method("column_count", method!(Matrix::column_count, 0))?;
    class.define_alias("column_size", "column_count")?;
    class.define_private_method("initialize_copy", method!(Matrix::initialize_copy, 1))?;
    class.define_method("to_a", method!(Matrix::to_a, 0))?;
    Ok(())
}
