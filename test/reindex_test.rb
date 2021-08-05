require_relative "test_helper"

class ReindexTest < Minitest::Test
  def test_record_inline
    store_names ["Product A", "Product B"], reindex: false

    product = Product.find_by!(name: "Product A")
    product.reindex(refresh: true)
    assert_search "product", ["Product A"]
  end

  def test_record_async
    store_names ["Product A", "Product B"], reindex: false

    product = Product.find_by!(name: "Product A")
    product.reindex(mode: :async)
    Product.search_index.refresh
    assert_search "product", ["Product A"]
  end

  def test_record_queue
    skip unless defined?(ActiveJob) && defined?(Redis)

    reindex_queue = Product.searchkick_index.reindex_queue
    reindex_queue.clear

    store_names ["Product A", "Product B"], reindex: false

    product = Product.find_by!(name: "Product A")
    product.reindex(mode: :queue)
    Product.search_index.refresh
    assert_search "product", []

    Searchkick::ProcessQueueJob.perform_now(class_name: "Product")
    Product.search_index.refresh
    assert_search "product", ["Product A"]
  end

  def test_relation_inline
    skip if nobrainer? || cequel?

    store_names ["Product A"]
    store_names ["Product B", "Product C"], reindex: false
    Product.where(name: "Product B").reindex(refresh: true)
    assert_search "product", ["Product A", "Product B"]
  end

  def test_relation_associations
    skip if nobrainer? || cequel?

    store_names ["Product A"]
    store = Store.create!(name: "Test")
    Product.create!(name: "Product B", store_id: store.id)
    store.products.reindex(refresh: true)
    assert_search "product", ["Product A", "Product B"]
  end

  def test_relation_should_index
    skip if nobrainer? || cequel?

    skip "TODO make pass in Searchkick 5"

    store_names ["Product A", "Product B"]
    Searchkick.callbacks(false) do
      Product.find_by(name: "Product B").update!(name: "DO NOT INDEX")
    end
    Product.where(name: "DO NOT INDEX").reindex
    Product.search_index.refresh
    assert_search "product", ["Product A"]
  end

  def test_relation_async
    skip "Not available yet"
  end

  def test_relation_queue
    skip "Not available yet"
  end

  def test_full_async
    store_names ["Product A"], reindex: false
    reindex = Product.reindex(async: true)
    assert_search "product", [], conversions: false

    index = Searchkick::Index.new(reindex[:index_name])
    index.refresh
    assert_equal 1, index.total_docs

    assert Searchkick.reindex_status(reindex[:name])

    Product.searchkick_index.promote(reindex[:index_name])
    assert_search "product", ["Product A"]
  end

  def test_full_async_should_index
    store_names ["Product A", "Product B", "DO NOT INDEX"], reindex: false
    reindex = Product.reindex(async: true)

    index = Searchkick::Index.new(reindex[:index_name])
    index.refresh
    assert_equal 2, index.total_docs
  end

  def test_full_async_wait
    store_names ["Product A"], reindex: false

    capture_io do
      Product.reindex(async: {wait: true})
    end

    assert_search "product", ["Product A"]
  end

  def test_full_async_non_integer_pk
    Sku.create(id: SecureRandom.hex, name: "Test")
    reindex = Sku.reindex(async: true)
    assert_search "sku", [], conversions: false

    index = Searchkick::Index.new(reindex[:index_name])
    index.refresh
    assert_equal 1, index.total_docs
  ensure
    Sku.destroy_all
  end

  def test_full_refresh_interval
    reindex = Product.reindex(refresh_interval: "30s", async: true, import: false)
    index = Searchkick::Index.new(reindex[:index_name])
    assert_nil Product.search_index.refresh_interval
    assert_equal "30s", index.refresh_interval

    Product.search_index.promote(index.name, update_refresh_interval: true)
    assert_equal "1s", index.refresh_interval
    assert_equal "1s", Product.search_index.refresh_interval
  end

  def test_full_resume
    assert Product.reindex(resume: true)
  end

  def test_full_refresh
    Product.reindex(refresh: true)
  end

  def test_full_partial_async
    store_names ["Product A"]
    # warn for now
    assert_warns "unsupported keywords: :async" do
      Product.reindex(:search_name, async: true)
    end
  end

  def test_callbacks_false
    Searchkick.callbacks(false) do
      store_names ["Product A", "Product B"]
    end
    assert_search "product", []
  end

  def test_callbacks_bulk
    Searchkick.callbacks(:bulk) do
      store_names ["Product A", "Product B"]
    end
    Product.search_index.refresh
    assert_search "product", ["Product A", "Product B"]
  end

  def test_callbacks_queue
    skip unless defined?(ActiveJob) && defined?(Redis)

    # TODO figure out which earlier test leaves records in index
    Product.reindex

    reindex_queue = Product.searchkick_index.reindex_queue
    reindex_queue.clear

    Searchkick.callbacks(:queue) do
      store_names ["Product A", "Product B"]
    end
    Product.searchkick_index.refresh
    assert_search "product", [], load: false, conversions: false
    assert_equal 2, reindex_queue.length

    Searchkick::ProcessQueueJob.perform_later(class_name: "Product")
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product B"], load: false
    assert_equal 0, reindex_queue.length

    Searchkick.callbacks(:queue) do
      Product.where(name: "Product B").destroy_all
      Product.create!(name: "Product C")
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product B"], load: false
    assert_equal 2, reindex_queue.length

    Searchkick::ProcessQueueJob.perform_later(class_name: "Product")
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product C"], load: false
    assert_equal 0, reindex_queue.length

    # ensure no error with empty queue
    Searchkick::ProcessQueueJob.perform_later(class_name: "Product")
  end

  def test_transaction
    skip unless activerecord?

    Product.transaction do
      store_names ["Product A"]
      raise ActiveRecord::Rollback
    end
    assert_search "*", []
  end
end
