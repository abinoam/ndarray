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

task default: %i[compile spec standard]
