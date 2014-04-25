require_relative "test_helper"

class TestFacets < Minitest::Unit::TestCase

  def setup
    super
    store [
      {name: "Product Show", latitude: 37.7833, longitude: 12.4167, store_id: 1, in_stock: true, color: "blue", price: 21},
      {name: "Product Hide", latitude: 29.4167, longitude: -98.5000, store_id: 2, in_stock: false, color: "green", price: 25},
      {name: "Product B", latitude: 43.9333, longitude: -122.4667, store_id: 2, in_stock: false, color: "red", price: 5},
      {name: "Foo", latitude: 43.9333, longitude: 12.4667, store_id: 3, in_stock: false, color: "yellow", price: 15}
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
  def test_constraints
    facets = Product.search("Product", where: { in_stock: true },
                            facets: [:store_id], include_constraints: true).facets

    assert_equal 1, facets['store_id']['terms'].size
    assert_equal [1], facets['store_id']['terms'].map{|f| f['term']}
  end

  def test_constraints_with_location
    facets = Product.search("Product", where: {location: {near: [37, -122], within: "2000mi"}},
                            facets: [:store_id], include_constraints: true).facets

    assert_equal 1, facets['store_id']['terms'].size
    assert_equal 2, facets['store_id']['terms'][0]['term']
  end

  def test_constraints_with_location_and_or_statement
    facets = Product.search("Product", where: {or: [[
      { location: {near: [37, -122], within: "2000mi"}}, {color: 'blue'}
    ]]}, facets: [:store_id], include_constraints: true).facets

    assert_equal 2, facets['store_id']['terms'].size
    assert_equal [1, 2], facets['store_id']['terms'].map{|f| f['term']}.sort
  end

  def test_facets_and_basic_constrains_together
    facets = Product.search("Product", where: { color: 'red' },
                            facets: {store_id: {where: {in_stock: false}}}, include_constraints: true).facets

    assert_equal 1, facets['store_id']['terms'].size
    assert_equal 2, facets['store_id']['terms'][0]['term']
    assert_equal 1, facets['store_id']['terms'][0]['count']
  end

  def test_facets_without_basic_constrains
    facets = Product.search("Product", where: { color: 'red' },
                            facets: {store_id: {where: {in_stock: false}}}, include_constraints: false).facets

    assert_equal 1, facets['store_id']['terms'].size
    assert_equal 2, facets['store_id']['terms'][0]['term']
    assert_equal 2, facets['store_id']['terms'][0]['count']
  end

  def test_do_not_include_current_facets_filter
    facets = Product.search("Product", where: { store_id: 2 },
                            facets: [:store_id], include_constraints: true).facets

    assert_equal 2, facets['store_id']['terms'].size
    assert_equal [1, 2], facets['store_id']['terms'].map{|f| f['term']}.sort
  end

  def test_do_not_include_current_facets_filter_with_complex_call
    facets = Product.search("Product", where: { store_id: 2, price: {gte: 4 }},
                            facets: [:store_id], include_constraints: true).facets

    assert_equal 2, facets['store_id']['terms'].size
    assert_equal [1, 2], facets['store_id']['terms'].map{|f| f['term']}.sort
  end

  def test_should_still_limit_results
    results = Product.search("*", where: { store_id: 2, price: {gte: 4 }},
                             facets: [:in_stock, :store_id, :color], include_constraints: false)

    facets = results.facets
    assert_equal 2, results.size
    assert_equal ["Product B", "Product Hide"], results.map(&:name).sort
    assert_equal 3, facets['store_id']['terms'].size
    assert_equal [1, 2, 3], facets['store_id']['terms'].map{|f| f['term']}.sort
  end
end
