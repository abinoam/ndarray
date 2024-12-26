# frozen_string_literal: true

require "mkmf"
require "rb_sys/mkmf"

create_rust_makefile("ndarray/ruby_ndarray_rust_ext")
