require_relative "test_helper"

class DangerousReindexTest < Minitest::Test
  def setup
    skip if mongoid2? || nobrainer? || activerecord_below41?
    super
  end

  def test_dangerous_reindex
    assert_raises(Searchkick::DangerousOperation) { Product.where(id: [1, 2, 3]).reindex }
  end

  def test_dangerous_index_associations
    Store.create!(name: "Test")
    assert_raises(Searchkick::DangerousOperation) { Store.first.products.reindex }
  end

  def test_dangerous_reindex_accepted
    store_names ["Product A", "Product B"]
    Product.where(name: "Product A").reindex(accept_danger: true)
    assert_search "product", ["Product A"]
  end

  def test_dangerous_reindex_inheritance
    assert_raises(Searchkick::DangerousOperation) { Dog.where(id: [1, 2, 3]).reindex }
  end
end
