require_relative "test_helper"

class CallbacksTest < Minitest::Test
  def test_false
    Searchkick.callbacks(false) do
      store_names ["Product A", "Product B"]
    end
    assert_search "product", []
  end

  def test_bulk
    Searchkick.callbacks(:bulk) do
      store_names ["Product A", "Product B"]
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product B"]
  end

  def test_queue
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

    perform_enqueued_jobs do
      Searchkick::ProcessQueueJob.perform_now(class_name: "Product")
    end
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

    perform_enqueued_jobs do
      Searchkick::ProcessQueueJob.perform_now(class_name: "Product")
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product C"], load: false
    assert_equal 0, reindex_queue.length

    # ensure no error with empty queue
    Searchkick::ProcessQueueJob.perform_now(class_name: "Product")
  end

  def test_disable_callbacks
    # make sure callbacks default to on
    assert Searchkick.callbacks?

    store_names ["product a"]

    Searchkick.disable_callbacks
    assert !Searchkick.callbacks?

    store_names ["product b"]
    assert_search "product", ["product a"]

    Searchkick.enable_callbacks
    Product.reindex

    assert_search "product", ["product a", "product b"]
  end
end
