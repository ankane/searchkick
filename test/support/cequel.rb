cequel =
  Cequel.connect(
    host: "127.0.0.1",
    port: 9042,
    keyspace: "searchkick_test",
    default_consistency: :all
  )
cequel.logger = $logger
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

class Song
  include Cequel::Record

  key :id, :timeuuid, auto: true
  column :name, :text
end

[Product, Store, Region, Speaker, Animal, Sku, Song].each(&:synchronize_schema)
