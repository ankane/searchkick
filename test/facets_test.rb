require_relative "test_helper"

class TestFacets < Minitest::Unit::TestCase

  def setup
    super
    store [
      {name: "Product Show", store_id: 1, in_stock: true, color: "blue", price: 21},
      {name: "Product Hide", store_id: 2, in_stock: false, color: "green", price: 25},
      {name: "Product B", store_id: 2, in_stock: false, color: "red", price: 5}
    ]
  end

  def test_basic
    assert_equal 2, Product.search("Product", facets: [:store_id]).facets["store_id"]["terms"].size
  end

  def test_where
    assert_equal 1, Product.search("Product", facets: {store_id: {where: {in_stock: true}}}).facets["store_id"]["terms"].size
  end

  def test_limit
    facet = Product.search("Product", facets: {store_id: {limit: 1}}).facets["store_id"]
    assert_equal 1, facet["terms"].size
    assert_equal 3, facet["total"]
    assert_equal 1, facet["other"]
  end

  def test_ranges
    price_ranges = [{to: 10}, {from: 10, to: 20}, {from: 20}]
    facet = Product.search("Product", facets: {price: {ranges: price_ranges}}).facets["price"]

    assert_equal 3, facet["ranges"].size
    assert_equal 10.0, facet["ranges"][0]["to"]
    assert_equal 20.0, facet["ranges"][2]["from"]
    assert_equal 1, facet["ranges"][0]["count"]
    assert_equal 0, facet["ranges"][1]["count"]
    assert_equal 2, facet["ranges"][2]["count"]
  end
end
