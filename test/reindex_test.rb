require_relative "test_helper"

class ReindexTest < Minitest::Test
  def test_scoped
    skip if nobrainer? || cequel?

    store_names ["Product A"]
    Searchkick.callbacks(false) do
      store_names ["Product B", "Product C"]
    end
    Product.where(name: "Product B").reindex(refresh: true)
    assert_search "product", ["Product A", "Product B"]
  end

  def test_associations
    skip if nobrainer? || cequel?

    store_names ["Product A"]
    store = Store.create!(name: "Test")
    Product.create!(name: "Product B", store_id: store.id)
    store.products.reindex(refresh: true)
    assert_search "product", ["Product A", "Product B"]
  end

  def test_async
    skip if !defined?(ActiveJob)

    Searchkick.callbacks(false) do
      store_names ["Product A"]
    end
    reindex = Product.reindex(async: true)
    assert_search "product", [], conversions: false

    index = Searchkick::Index.new(reindex[:index_name])
    index.refresh
    assert_equal 1, index.total_docs

    Product.searchkick_index.promote(reindex[:index_name])
    assert_search "product", ["Product A"]
  end

  def test_async_non_integer_pk
    skip if !defined?(ActiveJob)

    Sku.create(id: SecureRandom.hex, name: "Test")
    reindex = Sku.reindex(async: true)
    assert_search "sku", [], conversions: false

    index = Searchkick::Index.new(reindex[:index_name])
    index.refresh
    assert_equal 1, index.total_docs
  end

  def test_refresh_interval
    reindex = Product.reindex(refresh_interval: "30s", async: true, import: false)
    index = Searchkick::Index.new(reindex[:index_name])
    assert_nil Product.search_index.refresh_interval
    assert_equal "30s", index.refresh_interval

    Product.search_index.promote(index.name, update_refresh_interval: true)
    assert_equal "1s", index.refresh_interval
    assert_equal "1s", Product.search_index.refresh_interval
  end
end
