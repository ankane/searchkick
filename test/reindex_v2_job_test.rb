require_relative "test_helper"

class ReindexV2JobTest < Minitest::Test
  def setup
    skip unless defined?(ActiveJob)
    super
  end

  def test_create
    product = Searchkick.callbacks(false) { Product.create!(name: "Boom") }
    Product.search_index.refresh
    assert_search "*", []
    Searchkick::ReindexV2Job.perform_later("Product", product.id.to_s)
    Product.search_index.refresh
    assert_search "*", ["Boom"]
  end

  def test_destroy
    product = Searchkick.callbacks(false) { Product.create!(name: "Boom") }
    Product.reindex
    assert_search "*", ["Boom"]
    Searchkick.callbacks(false) { product.destroy }
    Searchkick::ReindexV2Job.perform_later("Product", product.id.to_s)
    Product.search_index.refresh
    assert_search "*", []
  end

  def test_callbacks_async
    Searchkick.callbacks(false) do
      store_names ['Topic B'], Topic
    end
    topic = Topic.where(name: "Topic B").first
    Searchkick::ReindexV2Job.perform_now(topic.class.name, topic.id.to_s)
    topic.reload
    assert_equal true, topic.before_called
    assert_equal true, topic.after_called
  end
end
