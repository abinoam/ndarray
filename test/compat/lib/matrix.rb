# frozen_string_literal: true

# Stand-in for the stdlib "matrix" library, used only by the compat suite:
# the upstream tests `require "matrix"` and talk to ::Matrix/::Vector, so we
# point those constants at NDArray's implementation.
require "ndarray"

Matrix = NDArray::Matrix
Vector = NDArray::Vector if defined?(NDArray::Vector)
