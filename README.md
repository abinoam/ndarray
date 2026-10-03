# NDArray

**NDArray** is a Ruby library that brings the power of Rust's [`ndarray`](https://docs.rs/ndarray/latest/ndarray/) crate to Ruby, enabling blazing-fast matrix operations. Designed as a proof of concept, this library demonstrates how binding Ruby to Rust can achieve hundreds or even thousands of times more speed for matrix calculations.

## Features

- **Hundreds to Thousands of Times Faster**:
  - For a `10x20` x `20x40` matrix multiplication, NDArray achieves **400x faster** performance compared to Ruby's `Matrix`.
  - For larger matrices like `1000x2000` x `2000x4000`, NDArray can be **1500x faster** and up to **2500x faster with multithreading**.
- **Current status**:
  - Alpha software. Currently supports 2D arrays only, with a primary focus on the dot product operation.
- **Ruby-Rust Integration**:
  - Powered by the [Magnus](https://github.com/matsadler/magnus) and [rb-sys](https://github.com/oxidize-rb/rb-sys) gems, enabling seamless Ruby-Rust bindings.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "ndarray", git: "https://github.com/abinoam/ndarray.git"
```

And then execute:

```bash
bundle install
```

Alternatively, you can install it manually:

```bash
git clone https://github.com/abinoam/ndarray.git
cd ndarray
bundle install
rake install
```

## Usage

```ruby
require "ndarray"

# Create two 2D matrices
matrix1 = NDArray.from_array([[1.0, 2.0], [3.0, 4.0]])
matrix2 = NDArray.from_array([[5.0, 6.0], [7.0, 8.0]])

# Perform a dot product
result = matrix1.dot(matrix2)

# Convert the result back to a Ruby array
puts result.to_a
# Output: [[19.0, 22.0], [43.0, 50.0]]
```

## Performance

NDArray leverages Rust's highly optimized `ndarray` crate to perform matrix calculations significantly faster than Ruby's `Matrix` library.

For example:

- **Small Matrices**:
  - `10x20` x `20x40` => **400x faster**
- **Large Matrices**:
  - `1000x2000` x `2000x4000` => **1500x to 2500x faster with multithreading**

## Inspiration

This project draws inspiration from the now-stale [NMatrix](https://github.com/SciRuby/nmatrix) project. More details can be found on the blog post: [400x Faster Matrix Multiplication for Ruby](https://abinoam.tl1n.com/400x-faster-matrix-multiplication-for-ruby/).

NDArray aims to explore how modern Rust libraries and Ruby bindings can achieve even greater performance while maintaining ease of use.

## Development

### Prerequisites

- Rust (version 1.85+)
- Ruby (version 3.1.0+)
- Bundler

### Setting Up

Clone the repository and install dependencies:

```bash
git clone https://github.com/abinoam/ndarray.git
cd ndarray
bin/setup
```

Run the test suite:

```bash
bundle exec rake spec
```

Launch an interactive console to experiment:

```bash
bin/console
```

### Continuous Integration

The project includes a GitHub Actions workflow that ensures compatibility with the latest versions of Ruby and Rust.

## Academic Origin

This project was created as part of the **Rust Programming Discipline** at **IMD (Instituto Metrópole Digital)** of **UFRN (Universidade Federal do Rio Grande do Norte)**. It was developed by **[Abinoam Praxedes Marques Junior](@abinoam)**, under the guidance of **[Professor Wedson Almeida](@wedsonaf)**.

## License

This project is licensed under the MIT License. See [LICENSE.txt](./LICENSE.txt) for details.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/abinoam/ndarray](https://github.com/abinoam/ndarray). This project follows standard Ruby conventions, and contributions are encouraged.
