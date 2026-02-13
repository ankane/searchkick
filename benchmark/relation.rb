require "bundler/setup"
Bundler.require(:default)
require "active_record"

class Product < ActiveRecord::Base
  searchkick
end

Product.all # initial Active Record allocations

stats = AllocationStats.trace do
  Product.search("apples").where(store_id: 1).where(in_stock: true).order(:name).limit(10).offset(50)
end
puts stats.allocations(alias_paths: true).to_text
