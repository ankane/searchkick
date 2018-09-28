NoBrainer.configure do |config|
  config.app_name = :searchkick
  config.environment = :test
end

class Product
  include NoBrainer::Document
  include NoBrainer::Document::Timestamps

  field :id,           type: Object
  field :name,         type: Text
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

class Song
  include NoBrainer::Document

  field :id,   type: Object
  field :name, type: String
end
