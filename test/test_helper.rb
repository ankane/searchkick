require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_record"

ENV["RACK_ENV"] = "test"

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

# Mongoid.configure do |config|
#   config.connect_to "searchkick_test"
# end

class Product < ActiveRecord::Base
  # include Mongoid::Document
  # include Mongoid::Attributes::Dynamic

  belongs_to :store

  searchkick \
    settings: {
      number_of_shards: 1,
      number_of_replicas: 0
    },
    synonyms: [
      ["clorox", "bleach"],
      ["scallion", "greenonion"],
      ["saranwrap", "plasticwrap"],
      ["qtip", "cottonswab"],
      ["burger", "hamburger"],
      ["bandaid", "bandag"]
    ],
    autocomplete: [:name],
    suggest: [:name, :color],
    conversions: "conversions",
    personalize: "user_ids"

  attr_accessor :conversions, :user_ids

  def search_data
    as_json.merge conversions: conversions, user_ids: user_ids
  end
end

class Store < ActiveRecord::Base
  # include Mongoid::Document
end

Product.tire.index.delete if Product.tire.index.exists?
Product.reindex
Product.reindex # run twice for both index paths

class MiniTest::Unit::TestCase

  def setup
    Product.destroy_all
  end

  protected

  def store(documents)
    documents.shuffle.each do |document|
      Product.create!(document)
    end
    Product.tire.index.refresh
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

  def assert_first(term, expected, options = {})
    assert_equal expected, Product.search(term, options).map(&:name).first
  end

end
