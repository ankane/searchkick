require_relative "test_helper"

class CallbacksTest < Minitest::Test
  def test_true_create
    Searchkick.callbacks(true) do
      store_names ["Product A", "Product B"]
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product B"]
  end

  def test_false_create
    Searchkick.callbacks(false) do
      store_names ["Product A", "Product B"]
    end
    Product.searchkick_index.refresh
    assert_search "product", []
  end

  def test_bulk_create
    Searchkick.callbacks(:bulk) do
      store_names ["Product A", "Product B"]
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product B"]
  end

  def test_queue
    skip unless defined?(ActiveJob) && defined?(Redis)

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
  end
end
