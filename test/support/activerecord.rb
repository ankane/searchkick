require "active_record"

# for debugging
ActiveRecord::Base.logger = $logger

# rails does this in activerecord/lib/active_record/railtie.rb
ActiveRecord.default_timezone = :utc
ActiveRecord::Base.time_zone_aware_attributes = true

# migrations
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

require_relative "apartment" if defined?(Apartment)

ActiveRecord::Migration.verbose = ENV["VERBOSE"]

ActiveRecord::Schema.define do
  create_table :products do |t|
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
    t.text :embedding
    t.text :embedding2
    t.text :embedding3
    t.text :embedding4
    t.timestamps null: true
  end

  create_table :stores do |t|
    t.string :name
  end

  create_table :regions do |t|
    t.string :name
    t.text :text
  end

  create_table :speakers do |t|
    t.string :name
  end

  create_table :animals do |t|
    t.string :name
    t.string :type
  end

  create_table :skus, id: :uuid do |t|
    t.string :name
  end

  create_table :songs do |t|
    t.string :name
  end

  create_table :bands do |t|
    t.string :name
    t.boolean :active
  end

 create_table :artists do |t|
    t.string :name
    t.boolean :active
    t.boolean :should_index
  end
end

class Product < ActiveRecord::Base
  belongs_to :store

  serialize :embedding, coder: JSON
  serialize :embedding2, coder: JSON
  serialize :embedding3, coder: JSON
  serialize :embedding4, coder: JSON
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

class Song < ActiveRecord::Base
end

class Band < ActiveRecord::Base
  default_scope { where(active: true).order(:name) }
end

class Artist < ActiveRecord::Base
  default_scope { where(active: true).order(:name) }
end
