require_relative "test_helper"

class TestReindexV2Job < Minitest::Test

  def setup
    super
    Searchkick.disable_callbacks
  end

  def teardown
    Searchkick.enable_callbacks
  end

  def test_create
    skip if !defined?(ActiveJob)

    product = Product.create!(name: "Boom")
    Product.searchkick_index.refresh
    assert_search "*", []
    Searchkick::ReindexV2Job.perform_later("Product", product.id.to_s)
    Product.searchkick_index.refresh
    assert_search "*", ["Boom"]
  end

  def test_destroy
    skip if !defined?(ActiveJob)

    product = Product.create!(name: "Boom")
    Product.reindex
    assert_search "*", ["Boom"]
    product.destroy
    Searchkick::ReindexV2Job.perform_later("Product", product.id.to_s)
    Product.searchkick_index.refresh
    assert_search "*", []
  end

end
