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

ActiveRecord::Migration.create_table :store, :force => true do |t|
end

File.delete("elasticsearch.log") if File.exists?("elasticsearch.log")
Tire.configure do
  logger "elasticsearch.log", :level => "debug"
  pretty true
end

class Product < ActiveRecord::Base
  belongs_to :store

  searchkick \
    settings: {
      number_of_shards: 1
    },
    synonyms: [
      ["clorox", "bleach"],
      ["scallion", "greenonion"],
      ["saranwrap", "plasticwrap"],
      ["qtip", "cotton swab"],
      ["burger", "hamburger"],
      ["bandaid", "bandag"]
    ]

  attr_accessor :conversions

  def search_data
    as_json.merge conversions: conversions
  end
end

class Store < ActiveRecord::Base
end

Product.reindex

class MiniTest::Unit::TestCase

  def setup
    Product.destroy_all
  end

  protected

  def store(documents)
    documents.each do |document|
      Product.create!(document)
    end
    Product.index.refresh
  end

  def store_names(names)
    store names.map{|name| {name: name} }
  end

  # no order
  def assert_search(term, expected, options = {})
    assert_equal expected.sort, Product.search(term, options).map(&:name).sort
  end

  def assert_order(term, expected, options = {})
    assert_equal expected, Product.search(term, options).map(&:name)
  end

end
