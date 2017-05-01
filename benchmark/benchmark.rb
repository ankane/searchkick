require "bundler/setup"
Bundler.require(:default)
require "active_record"
require "benchmark"
require "active_support/notifications"

ActiveSupport::Notifications.subscribe "request.searchkick" do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  p event.duration
end

ActiveJob::Base.queue_adapter = :sidekiq

Searchkick.redis = Redis.new

ActiveRecord::Base.default_timezone = :utc
ActiveRecord::Base.time_zone_aware_attributes = true
# ActiveRecord::Base.establish_connection adapter: "sqlite3", database: "/tmp/searchkick"
ActiveRecord::Base.establish_connection "postgresql://localhost/searchkick_demo_development"
# ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveJob::Base.logger = nil

class Product < ActiveRecord::Base
  searchkick batch_size: 1000

  def search_data
    {
      name: name,
      color: color,
      store_id: store_id
    }
  end
end

total_docs = 100000

# ActiveRecord::Migration.create_table :products, force: :cascade do |t|
#   t.string :name
#   t.string :color
#   t.integer :store_id
# end

# Product.import ["name", "color", "store_id"], total_docs.times.map { |i| ["Product #{i}", ["red", "blue"].sample, rand(10)] }

puts "Imported"

result = nil
report = nil
stats = nil

# p GetProcessMem.new.mb

Product.searchkick_index.delete rescue nil

time =
  Benchmark.realtime do
    # result = RubyProf.profile do
    # report = MemoryProfiler.report do
    # stats = AllocationStats.trace do
    reindex = Product.reindex(async: true)
    p reindex
    # end

    60.times do |i|
      if reindex.is_a?(Hash)
        docs = Searchkick::Index.new(reindex[:index_name]).total_docs
      else
        docs = Product.searchkick_index.total_docs
      end
      puts "#{i}: #{docs}"
      if docs == total_docs
        break
      end
      p Searchkick.reindex_status(reindex[:index_name]) if reindex.is_a?(Hash)
      sleep(1)
      # Product.searchkick_index.refresh
    end
  end

# p GetProcessMem.new.mb

puts time.round(1)


if result
  printer = RubyProf::GraphPrinter.new(result)
  printer.print(STDOUT, min_percent: 5)
end

if report
  puts report.pretty_print
end

if stats
  puts result.allocations(alias_paths: true).group_by(:sourcefile, :class).to_text
end
