# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

require "rb_sys/extensiontask"

task build: :compile

GEMSPEC = Gem::Specification.load("ndarray.gemspec")

RbSys::ExtensionTask.new("ruby_ndarray_rust_ext", GEMSPEC) do |ext|
  ext.lib_dir = "lib/ndarray"
end

COMPAT_PASSING = "test/compat/passing.txt"

def compat_passing_tests
  File.readlines(COMPAT_PASSING, chomp: true).reject { |line| line.strip.empty? || line.start_with?("#") }
end

# Runs test/compat/run.rb, returning whether it succeeded and the names of the
# tests that ran and passed.
def run_compat(env = {}, *args)
  require "json"
  require "tmpdir"

  Dir.mktmpdir do |dir|
    path = File.join(dir, "results.json")
    success = system(env.merge("COMPAT_RESULTS" => path), FileUtils::RUBY, "test/compat/run.rb", *args)
    [success, JSON.parse(File.read(path))]
  end
end

desc "Run the upstream Matrix tests listed in #{COMPAT_PASSING}"
task compat: :compile do
  tests = compat_passing_tests
  next puts "compat: no tests listed in #{COMPAT_PASSING} yet" if tests.empty?

  success, results = run_compat("COMPAT_ONLY" => tests.join(" "))
  unless (unknown = tests - results["ran"]).empty?
    abort "compat: unknown tests in #{COMPAT_PASSING}: #{unknown.join(", ")}"
  end
  abort "compat: upstream Matrix tests failed" unless success
end

namespace :compat do
  desc "Run the whole upstream Matrix suite and report progress (never fails)"
  task report: :compile do
    _, results = run_compat({}, "--verbose=silent")
    ran, passed = results.values_at("ran", "passed")
    listed = compat_passing_tests

    puts format("Upstream Matrix compatibility: %d/%d tests passing (%.1f%%)",
      passed.size, ran.size, 100.0 * passed.size / ran.size)
    unless (unlisted = passed - listed).empty?
      puts "\nPassing but not listed in #{COMPAT_PASSING}:", unlisted.map { |test| "  #{test}" }
    end
    unless (regressed = listed - passed).empty?
      puts "\nListed in #{COMPAT_PASSING} but not passing:", regressed.map { |test| "  #{test}" }
    end
  end
end

task default: %i[compile spec standard]
