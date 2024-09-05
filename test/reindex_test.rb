require_relative "test_helper"

class ReindexTest < Minitest::Test
  def test_record_inline
    store_names ["Product A", "Product B"], reindex: false

    product = Product.find_by!(name: "Product A")
    assert_equal true, product.reindex(refresh: true)
    assert_search "product", ["Product A"]
  end

  def test_record_destroyed
    store_names ["Product A", "Product B"]

    product = Product.find_by!(name: "Product A")
    product.destroy
    Product.searchkick_index.refresh
    assert_equal true, product.reindex
  end

  def test_record_async
    store_names ["Product A", "Product B"], reindex: false

    product = Product.find_by!(name: "Product A")
    perform_enqueued_jobs do
      assert_equal true, product.reindex(mode: :async)
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A"]
  end

  def test_record_queue
    reindex_queue = Product.searchkick_index.reindex_queue
    reindex_queue.clear

    store_names ["Product A", "Product B"], reindex: false

    product = Product.find_by!(name: "Product A")
    assert_equal true, product.reindex(mode: :queue)
    Product.searchkick_index.refresh
    assert_search "product", []

    perform_enqueued_jobs do
      Searchkick::ProcessQueueJob.perform_now(class_name: "Product")
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A"]
  end

  def test_record_index
    store_names ["Product A", "Product B"], reindex: false

    product = Product.find_by!(name: "Product A")
    assert_equal true, Product.searchkick_index.reindex([product], refresh: true)
    assert_search "product", ["Product A"]
  end

  def test_relation_inline
    store_names ["Product A"]
    store_names ["Product B", "Product C"], reindex: false
    Product.where(name: "Product B").reindex(refresh: true)
    assert_search "product", ["Product A", "Product B"]
  end

  def test_relation_associations
    store_names ["Product A"]
    store = Store.create!(name: "Test")
    Product.create!(name: "Product B", store_id: store.id)
    assert_equal true, store.products.reindex(refresh: true)
    assert_search "product", ["Product A", "Product B"]
  end

  def test_relation_scoping
    store_names ["Product A", "Product B"]
    Product.dynamic_data = lambda do
      {
        name: "Count #{Product.count}"
      }
    end
    Product.where(name: "Product A").reindex(refresh: true)
    assert_search "count", ["Count 2"], load: false
  ensure
    Product.dynamic_data = nil
  end

  def test_relation_scoping_restored
    # TODO add test for Mongoid
    skip unless activerecord?

    assert_nil Product.current_scope
    Product.where(name: "Product A").scoping do
      scope = Product.current_scope
      refute_nil scope

      Product.all.reindex(refresh: true)

      # note: should be reset even if we don't do it
      assert_equal scope, Product.current_scope
    end
    assert_nil Product.current_scope
  end

  def test_relation_should_index
    store_names ["Product A", "Product B"]
    Searchkick.callbacks(false) do
      Product.find_by(name: "Product B").update!(name: "DO NOT INDEX")
    end
    assert_equal true, Product.where(name: "DO NOT INDEX").reindex
    Product.searchkick_index.refresh
    assert_search "product", ["Product A"]
  end

  def test_relation_async
    store_names ["Product A"]
    store_names ["Product B", "Product C"], reindex: false
    perform_enqueued_jobs do
      Product.where(name: "Product B").reindex(mode: :async)
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product B"]
  end

  def test_relation_async_should_index
    store_names ["Product A", "Product B"]
    Searchkick.callbacks(false) do
      Product.find_by(name: "Product B").update!(name: "DO NOT INDEX")
    end
    perform_enqueued_jobs do
      assert_equal true, Product.where(name: "DO NOT INDEX").reindex(mode: :async)
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A"]
  end

  def test_relation_async_routing
    store_names ["Store A"], Store, reindex: false
    perform_enqueued_jobs do
      Store.where(name: "Store A").reindex(mode: :async)
    end
    Store.searchkick_index.refresh
    assert_search "*", ["Store A"], {routing: "Store A"}, Store
  end

  def test_relation_queue
    reindex_queue = Product.searchkick_index.reindex_queue
    reindex_queue.clear

    store_names ["Product A"]
    store_names ["Product B", "Product C"], reindex: false

    Product.where(name: "Product B").reindex(mode: :queue)
    Product.searchkick_index.refresh
    assert_search "product", ["Product A"]

    perform_enqueued_jobs do
      Searchkick::ProcessQueueJob.perform_now(class_name: "Product")
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product B"]
  end

  def test_relation_queue_all
    reindex_queue = Product.searchkick_index.reindex_queue
    reindex_queue.clear

    store_names ["Product A"]
    store_names ["Product B", "Product C"], reindex: false

    Product.all.reindex(mode: :queue)
    Product.searchkick_index.refresh
    assert_search "product", ["Product A"]

    perform_enqueued_jobs do
      Searchkick::ProcessQueueJob.perform_now(class_name: "Product")
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product B", "Product C"]
  end

  def test_relation_queue_routing
    reindex_queue = Store.searchkick_index.reindex_queue
    reindex_queue.clear

    store_names ["Store A"], Store, reindex: false
    Store.where(name: "Store A").reindex(mode: :queue)
    Store.searchkick_index.refresh
    assert_search "*", [], {}, Store

    perform_enqueued_jobs do
      Searchkick::ProcessQueueJob.perform_now(class_name: "Store")
    end
    Store.searchkick_index.refresh
    assert_search "*", ["Store A"], {routing: "Store A"}, Store
  end

  def test_relation_index
    store_names ["Product A"]
    store_names ["Product B", "Product C"], reindex: false
    Product.searchkick_index.reindex(Product.where(name: "Product B"), refresh: true)
    assert_search "product", ["Product A", "Product B"]
  end

  def test_full_async
    store_names ["Product A"], reindex: false
    reindex = nil
    perform_enqueued_jobs do
      reindex = Product.reindex(mode: :async)
      assert_search "product", [], conversions: false
    end

    index = Searchkick::Index.new(reindex[:index_name])
    index.refresh
    assert_equal 1, index.total_docs

    reindex_status = Searchkick.reindex_status(reindex[:name])
    assert_equal true, reindex_status[:completed]
    assert_equal 0, reindex_status[:batches_left]

    Product.searchkick_index.promote(reindex[:index_name])
    assert_search "product", ["Product A"]
  end

  def test_full_async_should_index
    store_names ["Product A", "Product B", "DO NOT INDEX"], reindex: false

    reindex = nil
    perform_enqueued_jobs do
      reindex = Product.reindex(mode: :async)
    end

    index = Searchkick::Index.new(reindex[:index_name])
    index.refresh
    assert_equal 2, index.total_docs
  end

  def test_full_async_wait
    store_names ["Product A"], reindex: false

    perform_enqueued_jobs do
      capture_io do
        Product.reindex(mode: :async, wait: true)
      end
    end

    assert_search "product", ["Product A"]
  end

  def test_full_async_non_integer_pk
    Sku.create(id: SecureRandom.hex, name: "Test")

    reindex = nil
    perform_enqueued_jobs do
      reindex = Sku.reindex(mode: :async)
      assert_search "sku", [], conversions: false
    end

    index = Searchkick::Index.new(reindex[:index_name])
    index.refresh
    assert_equal 1, index.total_docs
  ensure
    Sku.destroy_all
  end

  def test_full_queue
    assert_warns "Full reindex does not support :queue mode - use :async mode instead" do
      Product.reindex(mode: :queue)
    end
  end

  def test_full_refresh_interval
    reindex = Product.reindex(refresh_interval: "30s", mode: :async, import: false)
    index = Searchkick::Index.new(reindex[:index_name])
    assert_nil Product.searchkick_index.refresh_interval
    assert_equal "30s", index.refresh_interval

    Product.searchkick_index.promote(index.name, update_refresh_interval: true)
    assert_equal "1s", index.refresh_interval
    assert_equal "1s", Product.searchkick_index.refresh_interval
  end

  def test_full_resume
    if mongoid?
      error = assert_raises(Searchkick::Error) do
        Product.reindex(resume: true)
      end
      assert_equal "Resume not supported for Mongoid", error.message
    else
      assert Product.reindex(resume: true)
    end
  end

  def test_full_refresh
    Product.reindex(refresh: true)
  end

  def test_full_partial_async
    store_names ["Product A"]
    Product.reindex(:search_name, mode: :async)
    assert_search "product", ["Product A"]
  end

  def test_wait_not_async
    error = assert_raises(ArgumentError) do
      Product.reindex(wait: false)
    end
    assert_equal "wait only available in :async mode", error.message
  end

  def test_object_index
    error = assert_raises(Searchkick::Error) do
      Product.searchkick_index.reindex(Object.new)
    end
    assert_equal "Cannot reindex object", error.message
  end

  def test_transaction
    skip unless activerecord?

    Product.transaction do
      store_names ["Product A"]
      raise ActiveRecord::Rollback
    end
    assert_search "*", []
  end

  def test_both_paths
    Product.searchkick_index.delete if Product.searchkick_index.exists?
    Product.reindex
    Product.reindex # run twice for both index paths
  end
end
