Mongoid.logger = $logger
Mongo::Logger.logger = $logger if defined?(Mongo::Logger)

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

class Song
  include Mongoid::Document

  field :name
end

class Band
  include Mongoid::Document

  field :name

  default_scope -> { where(name: "Test") }
end
