require_relative "test_helper"

class ReindexV2JobTest < Minitest::Test
  def test_create
    product = Searchkick.callbacks(false) { Product.create!(name: "Boom") }
    Product.searchkick_index.refresh
    assert_search "*", []
    Searchkick::ReindexV2Job.perform_now("Product", product.id.to_s)
    Product.searchkick_index.refresh
    assert_search "*", ["Boom"]
  end

  def test_destroy
    product = Searchkick.callbacks(false) { Product.create!(name: "Boom") }
    Product.reindex
    assert_search "*", ["Boom"]
    Searchkick.callbacks(false) { product.destroy }
    Searchkick::ReindexV2Job.perform_now("Product", product.id.to_s)
    Product.searchkick_index.refresh
    assert_search "*", []
  end
end
