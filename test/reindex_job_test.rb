require_relative "test_helper"

class TestReindexJob < Minitest::Unit::TestCase

  def setup
    super
    Searchkick.disable_callbacks
  end

  def teardown
    Searchkick.enable_callbacks
  end

  def test_create
    Product.create!(id: 1, name: "Boom")
    Product.searchkick_index.refresh
    assert_search "*", []
    Searchkick::ReindexJob.new("Product", 1).perform
    Product.searchkick_index.refresh
    assert_search "*", ["Boom"]
  end

  def test_destroy
    product = Product.create!(id: 1, name: "Boom")
    Product.reindex
    assert_search "*", ["Boom"]
    product.destroy
    Searchkick::ReindexJob.new("Product", 1).perform
    Product.searchkick_index.refresh
    assert_search "*", []
  end

end
