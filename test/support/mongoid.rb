Mongoid.logger = $logger
Mongo::Logger.logger = $logger if defined?(Mongo::Logger)

Mongoid.configure do |config|
  config.connect_to "searchkick_test", server_selection_timeout: 1
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
  field :embedding, type: Array
  field :embedding2, type: Array
  field :factors, type: Array
  field :vector, type: Array
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
  field :active, type: Mongoid::Boolean

  default_scope -> { where(active: true).order(name: 1) }
end

class Artist
  include Mongoid::Document

  field :name
  field :active, type: Mongoid::Boolean
  field :should_index, type: Mongoid::Boolean

  default_scope -> { where(active: true).order(name: 1) }
end
