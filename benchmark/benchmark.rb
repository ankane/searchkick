require "bundler/setup"
Bundler.require(:default)
require "active_record"
require "benchmark"

ActiveRecord::Base.default_timezone = :utc
ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

ActiveRecord::Migration.create_table :products do |t|
  t.string :name
  t.string :color
  t.integer :store_id
end

class Product < ActiveRecord::Base
  searchkick batch_size: 100
end

Product.import ["name", "color", "store_id"], 100000.times.map { |i| ["Product #{i}", ["red", "blue"].sample, rand(10)] }

puts "Imported"

result = nil

time =
  Benchmark.realtime do
    # result = RubyProf.profile do
      Product.reindex(refresh_interval: "30s")
    # end
  end

puts time.round(1)
puts Product.searchkick_index.total_docs

# printer = RubyProf::GraphPrinter.new(result)
# printer.print(STDOUT, min_percent: 2)

# puts Product.count
