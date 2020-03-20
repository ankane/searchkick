require "active_record"

# for debugging
ActiveRecord::Base.logger = $logger

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

ActiveRecord::Migration.create_table :songs do |t|
  t.string :name
end

ActiveRecord::Migration.create_table :bands do |t|
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

class Song < ActiveRecord::Base
end

class Band < ActiveRecord::Base
  default_scope { where(name: "Test") }
end
