require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.pattern = "test/**/*_test.rb"
end

task default: :test

# to test in parallel, uncomment and run:
# rake parallel:test
# require "parallel_tests/tasks"
