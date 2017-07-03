require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "logger"
require "active_support/core_ext" if defined?(NoBrainer)
require "active_support/notifications"

Searchkick.index_suffix = ENV["TEST_ENV_NUMBER"]

ENV["RACK_ENV"] = "test"

Minitest::Test = Minitest::Unit::TestCase unless defined?(Minitest::Test)

if !defined?(ParallelTests) || ParallelTests.first_process?
  File.delete("elasticsearch.log") if File.exist?("elasticsearch.log")
end

Searchkick.client.transport.logger = Logger.new("elasticsearch.log")
Searchkick.search_timeout = 5

if defined?(Redis)
  if defined?(ConnectionPool)
    Searchkick.redis = ConnectionPool.new { Redis.new }
  else
    Searchkick.redis = Redis.new
  end
end

puts "Running against Elasticsearch #{Searchkick.server_version}"

I18n.config.enforce_available_locales = true

if defined?(ActiveJob)
  ActiveJob::Base.logger = nil
  ActiveJob::Base.queue_adapter = :inline
end

ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT) if ENV["NOTIFICATIONS"]

def elasticsearch_below50?
  Searchkick.server_below?("5.0.0-alpha1")
end

def elasticsearch_below22?
  Searchkick.server_below?("2.2.0")
end

def nobrainer?
  defined?(NoBrainer)
end

def cequel?
  defined?(Cequel)
end

if defined?(Mongoid)
  Mongoid.logger.level = Logger::INFO
  Mongo::Logger.logger.level = Logger::INFO if defined?(Mongo::Logger)

  Mongoid.configure do |config|
    config.connect_to "searchkick_test"
  end

  class Product
    include Mongoid::Document
    include Mongoid::Timestamps

    field :name
    field :store_id, type: Integer
    field :in_stock, type: Boolean
    field :backordered, type: Boolean
    field :orders_count, type: Integer
    field :found_rate, type: BigDecimal
    field :price, type: Integer
    field :color
    field :latitude, type: BigDecimal
    field :longitude, type: BigDecimal
    field :description
    field :alt_description
  end

  class Store
    include Mongoid::Document
    has_many :products

    field :name
  end

  class Region
    include Mongoid::Document

    field :name
    field :text
  end

  class Speaker
    include Mongoid::Document

    field :name
  end

  class Animal
    include Mongoid::Document

    field :name
  end

  class Dog < Animal
  end

  class Cat < Animal
  end

  class Sku
    include Mongoid::Document

    field :name
  end
elsif defined?(NoBrainer)
  NoBrainer.configure do |config|
    config.app_name = :searchkick
    config.environment = :test
  end

  class Product
    include NoBrainer::Document
    include NoBrainer::Document::Timestamps

    field :id,           type: Object
    field :name,         type: String
    field :in_stock,     type: Boolean
    field :backordered,  type: Boolean
    field :orders_count, type: Integer
    field :found_rate
    field :price,        type: Integer
    field :color,        type: String
    field :latitude
    field :longitude
    field :description, type: String
    field :alt_description, type: String

    belongs_to :store, validates: false
  end

  class Store
    include NoBrainer::Document

    field :id,   type: Object
    field :name, type: String
  end

  class Region
    include NoBrainer::Document

    field :id,   type: Object
    field :name, type: String
    field :text, type: Text
  end

  class Speaker
    include NoBrainer::Document

    field :id,   type: Object
    field :name, type: String
  end

  class Animal
    include NoBrainer::Document

    field :id,   type: Object
    field :name, type: String
  end

  class Dog < Animal
  end

  class Cat < Animal
  end

  class Sku
    include NoBrainer::Document

    field :id,   type: String
    field :name, type: String
  end
elsif defined?(Cequel)
  cequel =
    Cequel.connect(
      host: "127.0.0.1",
      port: 9042,
      keyspace: "searchkick_test",
      default_consistency: :all
    )
  # cequel.logger = ActiveSupport::Logger.new(STDOUT)
  cequel.schema.drop! if cequel.schema.exists?
  cequel.schema.create!
  Cequel::Record.connection = cequel

  class Product
    include Cequel::Record

    key :id, :uuid, auto: true
    column :name, :text, index: true
    column :store_id, :int
    column :in_stock, :boolean
    column :backordered, :boolean
    column :orders_count, :int
    column :found_rate, :decimal
    column :price, :int
    column :color, :text
    column :latitude, :decimal
    column :longitude, :decimal
    column :description, :text
    column :alt_description, :text
    column :created_at, :timestamp
  end

  class Store
    include Cequel::Record

    key :id, :timeuuid, auto: true
    column :name, :text

    # has issue with id serialization
    def search_data
      {
        name: name
      }
    end
  end

  class Region
    include Cequel::Record

    key :id, :timeuuid, auto: true
    column :name, :text
    column :text, :text
  end

  class Speaker
    include Cequel::Record

    key :id, :timeuuid, auto: true
    column :name, :text
  end

  class Animal
    include Cequel::Record

    key :id, :timeuuid, auto: true
    column :name, :text

    # has issue with id serialization
    def search_data
      {
        name: name
      }
    end
  end

  class Dog < Animal
  end

  class Cat < Animal
  end

  class Sku
    include Cequel::Record

    key :id, :uuid
    column :name, :text
  end

  [Product, Store, Region, Speaker, Animal].each(&:synchronize_schema)
else
  require "active_record"

  # for debugging
  # ActiveRecord::Base.logger = Logger.new(STDOUT)

  # rails does this in activerecord/lib/active_record/railtie.rb
  ActiveRecord::Base.default_timezone = :utc
  ActiveRecord::Base.time_zone_aware_attributes = true

  # migrations
  ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

  ActiveRecord::Base.raise_in_transactional_callbacks = true if ActiveRecord::VERSION::STRING.start_with?("4.2.")

  if defined?(Apartment)
    class Rails
      def self.env
        ENV["RACK_ENV"]
      end
    end

    tenants = ["tenant1", "tenant2"]
    Apartment.configure do |config|
      config.tenant_names = tenants
      config.database_schema_file = false
      config.excluded_models = ["Product", "Store", "Animal", "Dog", "Cat"]
    end

    class Tenant < ActiveRecord::Base
      searchkick index_prefix: -> { Apartment::Tenant.current }
    end

    tenants.each do |tenant|
      begin
        Apartment::Tenant.create(tenant)
      rescue Apartment::TenantExists
        # do nothing
      end
      Apartment::Tenant.switch!(tenant)

      ActiveRecord::Migration.create_table :tenants, force: true do |t|
        t.string :name
        t.timestamps null: true
      end

      Tenant.reindex
    end

    Apartment::Tenant.reset
  end

  ActiveRecord::Migration.create_table :products do |t|
    t.string :name
    t.integer :store_id
    t.boolean :in_stock
    t.boolean :backordered
    t.integer :orders_count
    t.decimal :found_rate
    t.integer :price
    t.string :color
    t.decimal :latitude, precision: 10, scale: 7
    t.decimal :longitude, precision: 10, scale: 7
    t.text :description
    t.text :alt_description
    t.timestamps null: true
  end

  ActiveRecord::Migration.create_table :stores do |t|
    t.string :name
  end

  ActiveRecord::Migration.create_table :regions do |t|
    t.string :name
    t.text :text
  end

  ActiveRecord::Migration.create_table :speakers do |t|
    t.string :name
  end

  ActiveRecord::Migration.create_table :animals do |t|
    t.string :name
    t.string :type
  end

  ActiveRecord::Migration.create_table :skus, id: :uuid do |t|
    t.string :name
  end

  class Product < ActiveRecord::Base
    belongs_to :store
  end

  class Store < ActiveRecord::Base
    has_many :products
  end

  class Region < ActiveRecord::Base
  end

  class Speaker < ActiveRecord::Base
  end

  class Animal < ActiveRecord::Base
  end

  class Dog < Animal
  end

  class Cat < Animal
  end

  class Sku < ActiveRecord::Base
  end
end

class Product
  searchkick \
    synonyms: [
      ["clorox", "bleach"],
      ["scallion", "greenonion"],
      ["saranwrap", "plasticwrap"],
      ["qtip", "cottonswab"],
      ["burger", "hamburger"],
      ["bandaid", "bandag"],
      ["UPPERCASE", "lowercase"],
      "lightbulb => led,lightbulb",
      "lightbulb => halogenlamp"
    ],
    suggest: [:name, :color],
    conversions: [:conversions],
    locations: [:location, :multiple_locations],
    text_start: [:name],
    text_middle: [:name],
    text_end: [:name],
    word_start: [:name],
    word_middle: [:name],
    word_end: [:name],
    highlight: [:name],
    searchable: [:name, :color],
    filterable: [:name, :color, :description],
    similarity: "BM25",
    match: ENV["MATCH"] ? ENV["MATCH"].to_sym : nil

  attr_accessor :conversions, :user_ids, :aisle, :details

  def search_data
    serializable_hash.except("id").merge(
      conversions: conversions,
      user_ids: user_ids,
      location: {lat: latitude, lon: longitude},
      multiple_locations: [{lat: latitude, lon: longitude}, {lat: 0, lon: 0}],
      aisle: aisle,
      details: details
    )
  end

  def should_index?
    name != "DO NOT INDEX"
  end

  def search_name
    {
      name: name
    }
  end
end

class Store
  searchkick \
    routing: true,
    merge_mappings: true,
    mappings: {
      store: {
        properties: {
          name: elasticsearch_below50? ? {type: "string", analyzer: "keyword"} : {type: "keyword"}
        }
      }
    }

  def search_document_id
    id
  end

  def search_routing
    name
  end
end

class Region
  searchkick \
    geo_shape: {
      territory: {tree: "quadtree", precision: "10km"}
    }

  attr_accessor :territory

  def search_data
    {
      name: name,
      text: text,
      territory: territory
    }
  end
end

class Speaker
  searchkick \
    conversions: ["conversions_a", "conversions_b"]

  attr_accessor :conversions_a, :conversions_b, :aisle

  def search_data
    serializable_hash.except("id").merge(
      conversions_a: conversions_a,
      conversions_b: conversions_b,
      aisle: aisle
    )
  end
end

class Animal
  searchkick \
    text_start: [:name],
    suggest: [:name],
    index_name: -> { "#{name.tableize}-#{Date.today.year}#{Searchkick.index_suffix}" },
    callbacks: defined?(ActiveJob) ? :async : true
    # wordnet: true
end

class Sku
  searchkick callbacks: defined?(ActiveJob) ? :async : true
end

Product.searchkick_index.delete if Product.searchkick_index.exists?
Product.reindex
Product.reindex # run twice for both index paths
Product.create!(name: "Set mapping")

Store.reindex
Animal.reindex
Speaker.reindex
Region.reindex

class Minitest::Test
  def setup
    Product.destroy_all
    Store.destroy_all
    Animal.destroy_all
    Speaker.destroy_all
    Sku.destroy_all
  end

  protected

  def store(documents, klass = Product)
    documents.shuffle.each do |document|
      klass.create!(document)
    end
    klass.searchkick_index.refresh
  end

  def store_names(names, klass = Product)
    store names.map { |name| {name: name} }, klass
  end

  # no order
  def assert_search(term, expected, options = {}, klass = Product)
    assert_equal expected.sort, klass.search(term, options).map(&:name).sort
  end

  def assert_order(term, expected, options = {}, klass = Product)
    assert_equal expected, klass.search(term, options).map(&:name)
  end

  def assert_equal_scores(term, options = {}, klass = Product)
    assert_equal 1, klass.search(term, options).hits.map { |a| a["_score"] }.uniq.size
  end

  def assert_first(term, expected, options = {}, klass = Product)
    assert_equal expected, klass.search(term, options).map(&:name).first
  end
end
