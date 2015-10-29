require_relative "test_helper"

class ReindexJobTest < Minitest::Test
  def setup
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
    Searchkick::ReindexJob.new("Product", product.id.to_s).perform
    Product.searchkick_index.refresh
    assert_search "*", ["Boom"]
  end

  def test_destroy
    product = Product.create!(name: "Boom")
    Product.reindex
    assert_search "*", ["Boom"]
    product.destroy
    Searchkick::ReindexJob.new("Product", product.id.to_s).perform
    Product.searchkick_index.refresh
    assert_search "*", []
  end
end
