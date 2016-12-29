require_relative "test_helper"

class ReindexTest < Minitest::Test
  def setup
    skip if nobrainer?
    super
  end

  def test_scoped
    store_names ["Product A"]
    Searchkick.callbacks(false) do
      store_names ["Product B", "Product C"]
    end
    Product.where(name: "Product B").reindex(refresh: true)
    assert_search "product", ["Product A", "Product B"]
  end

  def test_associations
    store_names ["Product A"]
    store = Store.create!(name: "Test")
    Product.create!(name: "Product B", store_id: store.id)
    store.products.reindex(refresh: true)
    assert_search "product", ["Product A", "Product B"]
  end
end
