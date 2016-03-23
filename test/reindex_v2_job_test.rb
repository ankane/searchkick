require_relative "test_helper"

class ReindexV2JobTest < Minitest::Test
  def setup
    skip unless defined?(ActiveJob)
    super
    Searchkick.disable_callbacks
  end

  def teardown
    Searchkick.enable_callbacks
  end

  def test_create
    product = Product.create!(name: "Boom")
    Product.searchkick_index.refresh
    assert_search "*", []
    Searchkick::ReindexV2Job.perform_later("Product", product.id.to_s)
    Product.searchkick_index.refresh
    assert_search "*", ["Boom"]
  end

  def test_destroy
    product = Product.create!(name: "Boom")
    Product.reindex
    assert_search "*", ["Boom"]
    product.destroy
    Searchkick::ReindexV2Job.perform_later("Product", product.id.to_s)
    Product.searchkick_index.refresh
    assert_search "*", []
  end

  def test_reindex_mutex
    job = Searchkick::ReindexV2Job.new
    assert_instance_of Mutex, job.reindex_mutex
  end
end
