require "bundler/gem_tasks"
require "rake/testtask"

task default: :test
Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end

# to test in parallel, uncomment and run:
# rake parallel:test
# require "parallel_tests/tasks"
