# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project

Ruby gem (`ndarray`) exposing Rust's `ndarray` crate to Ruby via Magnus + rb-sys. Alpha/proof of concept: only 2D `f64` arrays, focused on matrix multiplication (`dot`). Requires Ruby >= 4.0 and a Rust toolchain.

## Commands

```bash
bin/setup                      # install dependencies
bundle exec rake               # default task: compile + spec + standard (what CI runs)
bundle exec rake compile       # build the Rust extension into lib/ndarray/
bundle exec rake spec          # run RSpec (does NOT recompile — run `compile` first after Rust changes)
bundle exec rspec spec/ndarray_spec.rb:20   # run a single example by line
bundle exec rake standard      # Ruby lint (standardrb, target Ruby 4.0)
bundle exec rake standard:fix  # autofix lint
cargo clippy                   # Rust lint (workspace root Cargo.toml points at ext/)
bin/console                    # IRB with the gem loaded
```

### Build output and checks

- Compiling the extension is very noisy (bindgen dumps thousands of `cargo:` lines). Redirect the output to a log file outside the repo and grep it instead of reading it whole:
  ```bash
  bundle exec rake > /tmp/rake.log 2>&1; echo exit=$?
  grep -E 'examples,|offenses|^error|^warning: ' /tmp/rake.log
  ```
  On a failure the real cause is near the end of the log: look for `--- stderr`, `error[E`, `panicked`, or messages such as `Stable API is needed`.
- Lint Ruby through `bundle exec rake standard`. Running `standardrb` directly also scans `target/` and reports its binaries as unprocessable.
- `cargo clippy` may report `Finished` straight from cache. Run `touch ext/ruby_ndarray_rust_ext/src/lib.rs` first to force a real check.

## Architecture

- **All behavior lives in Rust**: `ext/ruby_ndarray_rust_ext/src/lib.rs`. The `NDArray` Ruby class is defined there via `#[magnus::wrap(class = "NDArray")]` wrapping an `Array2<f64>`, and methods are registered in the `#[magnus::init]` function (`from_array` singleton, `dot`, `to_a`). Adding a Ruby method means implementing it on the Rust struct and registering it in `init`.
- `lib/ndarray.rb` only requires the version and the compiled `.so` (`lib/ndarray/ruby_ndarray_rust_ext.so`), then reopens `NDArray` (currently just `NDArray::Error`). The `.so` is a build artifact produced by `rake compile`.
- Build wiring: `Rakefile` uses `RbSys::ExtensionTask` named `ruby_ndarray_rust_ext` with `lib_dir = "lib/ndarray"`; `ext/ruby_ndarray_rust_ext/extconf.rb` calls `create_rust_makefile("ndarray/ruby_ndarray_rust_ext")`. These names must stay consistent with the crate name in `ext/ruby_ndarray_rust_ext/Cargo.toml` and the `require_relative` in `lib/ndarray.rb`.
- Rust dependencies go in `ext/ruby_ndarray_rust_ext/Cargo.toml`; the root `Cargo.toml` is only a workspace pointer for tooling.
- Errors raised from Rust use `magnus::Error::new(ruby.exception_arg_error(), ...)` (taking `ruby: &Ruby` as the first argument), surfacing as Ruby `ArgumentError` (e.g. `dot` with incompatible dimensions).
- `sig/ndarray.rbs` holds RBS signatures (currently minimal).

## Workflow

Never commit directly to `master`. Do all work on a separate branch, push it, and open a pull request; changes reach `master` only by merging that PR.

For dependency/toolchain upgrades (Bundler, gems, magnus/rb-sys/ndarray, Rust edition, minimum Ruby, CI matrix), follow `.claude/skills/update-dependencies/SKILL.md`: one atomic commit per upgrade step.

## Commits

Do not add AI attribution trailers (e.g. `Co-Authored-By: Claude ...`) or "Generated with ..." lines to commit messages or PR descriptions.
