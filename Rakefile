require "bundler/gem_tasks"
require "rake/testtask"

begin
  require "parallel_tests/tasks"
  require "shellwords"
rescue LoadError
  # do nothing
end

task default: :test
Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
  t.warning = false
end

task :benchmark do
  require_relative "benchmark/benchmark"
end
