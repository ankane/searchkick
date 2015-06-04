require_relative "test_helper"
require "active_support/core_ext"

class TestAggregations < Minitest::Test

  def setup
    super
    store [
           {name: "Product Show", latitude: 37.7833, longitude: 12.4167, store_id: 1, in_stock: true, color: "blue", price: 21, created_at: 2.days.ago},
           {name: "Product Hide", latitude: 29.4167, longitude: -98.5000, store_id: 2, in_stock: false, color: "green", price: 25, created_at: 2.days.from_now},
           {name: "Product B", latitude: 43.9333, longitude: -122.4667, store_id: 2, in_stock: false, color: "red", price: 5},
           {name: "Foo", latitude: 43.9333, longitude: 12.4667, store_id: 3, in_stock: false, color: "yellow", price: 15}
          ]
  end

  def test_basic
    assert_equal ({1 => 1, 2 => 2}), store_bucket_aggregation(aggregations: [:store_id])
  end

  def test_field
    assert_equal ({1 => 1, 2 => 2}), store_bucket_aggregation(aggregations: {store_id: {}})
    assert_equal ({1 => 1, 2 => 2}), store_bucket_aggregation(aggregations: {store_id: {field: "store_id"}})
    assert_equal ({1 => 1, 2 => 2}), store_bucket_aggregation({aggregations: {store_id_new: {field: "store_id"}}}, "store_id_new")
  end

  def test_ranges
    price_ranges = [{to: 10}, {from: 10, to: 20}, {from: 20}]
    aggregation = Product.search("Product", aggregations: {price: {ranges: price_ranges}}).aggregations["price"]

    assert_equal 3, aggregation["buckets"].size
    assert_equal 10.0, aggregation["buckets"][0]["to"]
    assert_equal 20.0, aggregation["buckets"][2]["from"]
    assert_equal 1, aggregation["buckets"][0]["doc_count"]
    assert_equal 0, aggregation["buckets"][1]["doc_count"]
    assert_equal 2, aggregation["buckets"][2]["doc_count"]
  end

  def test_stats
    options = {where: {store_id: 2}, aggregations: {store_id: {stats: true}}}
    aggregations = Product.search("Product", options).aggregations["store_id"]
    expected_aggregations_keys = %w(count min max avg sum)
    assert_equal expected_aggregations_keys, aggregations.keys
  end

  def test_smart_aggregations
    options = {where: {store_id: 2}, aggregations: [:store_id], smart_aggregations: true}
    assert_equal ({2 => 2}), store_bucket_aggregation(options)
  end

  protected
  def store_bucket_aggregation(options, aggregation_key="store_id")
    Hash[Product.search("Product", options).aggregations[aggregation_key]["buckets"].map { |v| [v["key"], v["doc_count"]] }]
  end
end
