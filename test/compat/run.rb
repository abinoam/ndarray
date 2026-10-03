# frozen_string_literal: true

# Runs the upstream ruby/matrix test suite against NDArray::Matrix.
#
#   ruby test/compat/run.rb [test-unit options]
#
# COMPAT_ONLY restricts the run to the space-separated TestClass#test_method
# names it holds (test-unit's own -n filters are ANDed together, so they can't
# select a list of tests). When COMPAT_RESULTS is set, the names of the tests
# that ran and of those that passed are written there as JSON.

root = File.expand_path("../..", __dir__)
upstream = File.join(root, "test/upstream/matrix")
abort "Missing #{upstream}: run `git submodule update --init`" unless File.directory?(File.join(upstream, "test"))

# The shim must come first so `require "matrix"` never loads the real gem.
$LOAD_PATH.unshift(File.join(root, "lib"), File.join(root, "test/compat/lib"), File.join(upstream, "test/lib"))

if (results_path = ENV["COMPAT_RESULTS"])
  require "json"
  results = {"ran" => [], "passed" => []}
  # Registered before test-unit's autorunner, so it runs after the suite.
  at_exit { File.write(results_path, JSON.generate(results)) }
end

require "helper"

if (only = ENV["COMPAT_ONLY"]&.split)
  Test::Unit::AutoRunner.prepare do |runner|
    runner.filters << ->(test) { only.include?("#{test.class}##{test.method_name}") }
  end
end

if results
  Test::Unit::TestCase.prepend(Module.new do
    define_method(:run) do |result, &block|
      super(result, &block).tap do
        name = "#{self.class}##{method_name}"
        results["ran"] << name
        results["passed"] << name if passed?
      end
    end
  end)
end

Dir[File.join(upstream, "test/matrix/test_*.rb")].sort.each { |file| require file }
