require "bundler/setup"
Bundler.require(:default)
require "active_record"

class Product < ActiveRecord::Base
  searchkick
end

relation = Product.search("apples")

stats = AllocationStats.trace do
  relation.where(store_id: 1).where(in_stock: true).order(:name).limit(10).offset(50)
end
puts stats.allocations(alias_paths: true).to_text
