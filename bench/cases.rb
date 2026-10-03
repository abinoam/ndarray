# frozen_string_literal: true

# Benchmark cases comparing ::Matrix with NDArray::Matrix.
#
# Each case lists the NDArray::Matrix methods it needs (cases are reported as
# "not implemented" until they all exist) and a `prepare` lambda. `prepare`
# receives the matrix class and the rows of an n x n matrix, builds whatever
# inputs it needs once, and returns the block whose speed is measured.
BENCH_CASES = [
  {
    name: "Matrix[*rows]",
    class_methods: %i[[]],
    prepare: ->(klass, rows) { -> { klass[*rows] } }
  },
  {
    name: "#[]",
    instance_methods: %i[[]],
    prepare: lambda do |klass, rows|
      matrix = klass[*rows]
      middle = rows.size / 2
      -> { matrix[middle, middle] }
    end
  },
  {
    name: "#==",
    instance_methods: %i[==],
    prepare: lambda do |klass, rows|
      # stdlib Matrix[] shares the row arrays, so give each matrix its own
      # fresh copy: Array#== short-circuits on identical (or #dup-shared) rows.
      matrix = klass[*rows.map { |row| row.map(&:itself) }]
      other = klass[*rows.map { |row| row.map(&:itself) }]
      -> { matrix == other }
    end
  }
].freeze
