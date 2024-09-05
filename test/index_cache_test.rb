require_relative "test_helper"

class IndexCacheTest < Minitest::Test
  def setup
    Product.class_variable_get(:@@searchkick_index_cache).clear
  end

  def test_default
    object_id = Product.searchkick_index.object_id
    3.times do
      assert_equal object_id, Product.searchkick_index.object_id
    end
  end

  def test_max_size
    starting_ids = object_ids(20)
    assert_equal starting_ids, object_ids(20)
    Product.searchkick_index(name: "other")
    refute_equal starting_ids, object_ids(20)
  end

  def test_thread_safe
    object_ids = with_threads { object_ids(20) }
    assert_equal object_ids[0], object_ids[1]
    assert_equal object_ids[0], object_ids[2]
  end

  # object ids can differ since threads progress at different speeds
  # test to make sure doesn't crash
  def test_thread_safe_max_size
    with_threads { object_ids(1000) }
  end

  private

  def object_ids(count)
    count.times.map { |i| Product.searchkick_index(name: "index#{i}").object_id }
  end

  def with_threads
    previous = Thread.report_on_exception
    begin
      Thread.report_on_exception = true
      3.times.map { Thread.new { yield } }.map(&:join).map(&:value)
    ensure
      Thread.report_on_exception = previous
    end
  end
end
