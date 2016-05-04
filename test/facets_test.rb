require_relative "test_helper"

class FacetsTest < Minitest::Test
  def setup
    skip unless elasticsearch_below20?
    super
    store [
      {name: "Product Show", latitude: 37.7833, longitude: 12.4167, store_id: 1, in_stock: true, color: "blue", price: 21, created_at: 2.days.ago},
      {name: "Product Hide", latitude: 29.4167, longitude: -98.5000, store_id: 2, in_stock: false, color: "green", price: 25, created_at: 2.days.from_now},
      {name: "Product B", latitude: 43.9333, longitude: -122.4667, store_id: 2, in_stock: false, color: "red", price: 5},
      {name: "Foo", latitude: 43.9333, longitude: 12.4667, store_id: 3, in_stock: false, color: "yellow", price: 15}
    ]
  end

  def test_basic
    assert_equal ({1 => 1, 2 => 2}), store_facet(facets: [:store_id])
  end

  def test_where
    assert_equal ({1 => 1}), store_facet(facets: {store_id: {where: {in_stock: true}}})
  end

  def test_field
    assert_equal ({1 => 1, 2 => 2}), store_facet(facets: {store_id: {}})
    assert_equal ({1 => 1, 2 => 2}), store_facet(facets: {store_id: {field: "store_id"}})
    assert_equal ({1 => 1, 2 => 2}), store_facet({facets: {store_id_new: {field: "store_id"}}}, "store_id_new")
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

  def test_ranges_dates
    ranges = [{to: 1.day.ago}, {from: 1.day.ago, to: 1.day.from_now}, {from: 1.day.from_now}]
    facet = Product.search("Product", facets: {created_at: {ranges: ranges}}).facets["created_at"]

    assert_equal 1, facet["ranges"][0]["count"]
    assert_equal 1, facet["ranges"][1]["count"]
    assert_equal 1, facet["ranges"][2]["count"]
  end

  def test_where_no_smart_facets
    assert_equal ({2 => 2}), store_facet(where: {color: "red"}, facets: {store_id: {where: {in_stock: false}}})
  end

  def test_smart_facets
    assert_equal ({1 => 1}), store_facet(where: {in_stock: true}, facets: [:store_id], smart_facets: true)
  end

  def test_smart_facets_where
    assert_equal ({2 => 1}), store_facet(where: {color: "red"}, facets: {store_id: {where: {in_stock: false}}}, smart_facets: true)
  end

  def test_smart_facets_skip_facet
    assert_equal ({1 => 1, 2 => 2}), store_facet(where: {store_id: 2}, facets: [:store_id], smart_facets: true)
  end

  def test_smart_facets_skip_facet_complex
    assert_equal ({1 => 1, 2 => 1}), store_facet(where: {store_id: 2, price: {gt: 5}}, facets: [:store_id], smart_facets: true)
  end

  def test_stats_facets
    skip if Gem::Version.new(Searchkick.server_version) >= Gem::Version.new("1.4.0")
    options = {where: {store_id: 2}, facets: {store_id: {stats: true}}}
    facets = Product.search("Product", options).facets["store_id"]["terms"]
    expected_facets_keys = %w(term count total_count min max total mean)
    assert_equal expected_facets_keys, facets.first.keys
  end

  protected

  def store_facet(options, facet_key = "store_id")
    Hash[Product.search("Product", options).facets[facet_key]["terms"].map { |v| [v["term"], v["count"]] }]
  end
end
