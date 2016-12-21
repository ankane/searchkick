require "bundler/setup"
Bundler.require(:default)
require "active_record"
require "benchmark"

ActiveRecord::Base.default_timezone = :utc
ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

ActiveRecord::Migration.create_table :products do |t|
  t.string :name
end

class Product < ActiveRecord::Base
  searchkick
end

Product.import ["name"], 30000.times.map { |i| ["Product #{i}"] }

puts "Imported"

time =
  Benchmark.realtime do
    Product.reindex #(threads: 3)
  end

puts time.round(1)
puts Product.searchkick_index.total_docs

# puts Product.count
