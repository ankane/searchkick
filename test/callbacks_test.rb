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

  def test_async
    assert_enqueued_jobs 2 do
      Searchkick.callbacks(:async) do
        store_names ["Product A", "Product B"]
      end
    end
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

  def test_record_async
    with_options({callbacks: :async}, Song) do
      assert_enqueued_jobs 1 do
        Song.create!(name: "Product A")
      end

      assert_enqueued_jobs 1 do
        Song.first.reindex
      end
    end
  end

  def test_relation_async
    with_options({callbacks: :async}, Song) do
      assert_enqueued_jobs 0 do
        Song.all.reindex
      end
    end
  end

  def test_bulk_batch_size_all_items_indexed
    names = (1..5).map { |i| "BatchProduct #{i}" }
    Searchkick.callbacks(:bulk, batch_size: 2) do
      store_names names
    end
    Product.searchkick_index.refresh
    assert_search "batchproduct", names
  end

  def test_bulk_batch_size_remainder_flushed_at_block_end
    Searchkick.callbacks(:bulk, batch_size: 3) do
      store_names ["Rem A", "Rem B"]
    end
    Product.searchkick_index.refresh
    assert_search "rem", ["Rem A", "Rem B"]
  end

  def test_bulk_batch_size_nesting_restores_outer_threshold
    outer_batch_size_during_inner = nil
    Searchkick.callbacks(:bulk, batch_size: 100) do
      Searchkick.callbacks(:bulk, batch_size: 50) do
        outer_batch_size_during_inner = Searchkick.bulk_batch_size
      end
      assert_equal 100, Searchkick.bulk_batch_size, "outer batch_size should be restored after inner block"
    end
    assert_equal 50, outer_batch_size_during_inner
    assert_nil Searchkick.bulk_batch_size, "batch_size should be nil after all blocks exit"
  end

  def test_bulk_batch_size_exception_nothing_flushed
    begin
      Searchkick.callbacks(:bulk, batch_size: 2) do
        store_names ["Safe A", "Safe B"]
        raise "intentional error"
      end
    rescue RuntimeError
      # expected
    end
    Product.searchkick_index.refresh
    assert_search "safe", []
  end

  def test_bulk_batch_size_fires_instrumentation_per_batch
    events = []
    subscription = ActiveSupport::Notifications.subscribe("request.searchkick") do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      events << event.payload[:count]
    end

    Searchkick.callbacks(:bulk, batch_size: 2) do
      store_names (1..5).map { |i| "InstrProduct #{i}" }
    end

    ActiveSupport::Notifications.unsubscribe(subscription)

    # 5 items with batch_size 2 → 3 batches (2, 2, 1)
    assert_equal 3, events.size
    assert_equal [2, 2, 1], events
  end

  def test_disable_callbacks
    # make sure callbacks default to on
    assert Searchkick.callbacks?

    store_names ["Product A"]

    Searchkick.disable_callbacks
    assert !Searchkick.callbacks?

    store_names ["Product B"]
    assert_search "product", ["Product A"]

    Searchkick.enable_callbacks
    Product.reindex

    assert_search "product", ["Product A", "Product B"]
  end
end
