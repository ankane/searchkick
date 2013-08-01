require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_record"

# for debugging
# ActiveRecord::Base.logger = Logger.new(STDOUT)

# rails does this in activerecord/lib/active_record/railtie.rb
ActiveRecord::Base.default_timezone = :utc
ActiveRecord::Base.time_zone_aware_attributes = true

# migrations
ActiveRecord::Base.establish_connection :adapter => "postgresql", :database => "searchkick_test"

ActiveRecord::Migration.create_table :products, :force => true do |t|
  t.string :name
  t.integer :store_id
  t.boolean :in_stock
  t.boolean :backordered
  t.integer :orders_count
  t.string :color
  t.timestamps
end

File.delete("elasticsearch.log") if File.exists?("elasticsearch.log")
Tire.configure { logger "elasticsearch.log", :level => "debug" }
