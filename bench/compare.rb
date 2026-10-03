# frozen_string_literal: true

# Compares the speed of NDArray::Matrix with the stdlib Matrix and prints a
# markdown table (run it with `rake bench`).
#
# Environment:
#   BENCH_SIZES  comma-separated matrix sizes (default: 10,100,300)
#   BENCH_TIME   seconds measured per entry (default: 1)
#   BENCH_CASES  only run the cases whose name includes this text

require "benchmark/ips"
require "matrix"
require "ndarray"
require_relative "cases"

sizes = ENV.fetch("BENCH_SIZES", "10,100,300").split(",").map { Integer(it) }
time = Float(ENV.fetch("BENCH_TIME", "1"))
element_types = {
  "Integer" => -> { rand(-100..100) },
  "Float" => -> { rand * 200 - 100 }
}

def implemented?(bench_case)
  bench_case.fetch(:class_methods, []).all? { NDArray::Matrix.singleton_class.method_defined?(it, false) } &&
    bench_case.fetch(:instance_methods, []).all? { NDArray::Matrix.method_defined?(it, false) }
end

def measure(time, entries)
  report = Benchmark.ips(quiet: true) do |x|
    x.config(time: time, warmup: time / 5)
    entries.each { |label, block| x.report(label, &block) }
  end
  report.entries.to_h { [it.label, it.ips] }
end

def format_ips(ips) = (ips >= 100) ? ips.round.to_s : format("%.2f", ips)

cases = BENCH_CASES.select { it[:name].include?(ENV.fetch("BENCH_CASES", "")) }

puts "| Case | Elements | n | Matrix (i/s) | NDArray::Matrix (i/s) | Speedup |"
puts "|---|---|---:|---:|---:|---:|"
cases.each do |bench_case|
  unless implemented?(bench_case)
    puts "| #{bench_case[:name]} | — | — | — | not implemented | — |"
    next
  end

  element_types.each do |type, element|
    sizes.each do |n|
      rows = Array.new(n) { Array.new(n) { element.call } }
      ips = measure(time, {
        "Matrix" => bench_case[:prepare].call(Matrix, rows),
        "NDArray::Matrix" => bench_case[:prepare].call(NDArray::Matrix, rows)
      })
      speedup = ips["NDArray::Matrix"] / ips["Matrix"]
      puts "| #{bench_case[:name]} | #{type} | #{n} | #{format_ips(ips["Matrix"])} | " \
        "#{format_ips(ips["NDArray::Matrix"])} | #{format("%.2fx", speedup)} |"
    end
  end
end
