require_relative "test_helper"

class TestFacets < Minitest::Unit::TestCase

  def setup
    super
    store [
      {name: "Product Show", store_id: 1, in_stock: true, color: "blue"},
      {name: "Product Hide", store_id: 2, in_stock: false, color: "green"},
      {name: "Product B", store_id: 2, in_stock: false, color: "red"}
    ]
  end

  def test_basic
    assert_equal 2, Product.search("Product", facets: [:store_id]).facets["store_id"]["terms"].size
  end

  def test_where
    assert_equal 1, Product.search("Product", facets: {store_id: {where: {in_stock: true}}}).facets["store_id"]["terms"].size
  end

end
