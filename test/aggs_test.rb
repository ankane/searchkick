require_relative "test_helper"

class AggsTest < Minitest::Test
  def setup
    super
    store [
      {name: "Product Show", latitude: 37.7833, longitude: 12.4167, store_id: 1, in_stock: true, color: "blue", price: 21, created_at: 2.days.ago},
      {name: "Product Hide", latitude: 29.4167, longitude: -98.5000, store_id: 2, in_stock: false, color: "green", price: 25, created_at: 2.days.from_now},
      {name: "Product B", latitude: 43.9333, longitude: -122.4667, store_id: 2, in_stock: false, color: "red", price: 5, created_at: Time.now},
      {name: "Foo", latitude: 43.9333, longitude: 12.4667, store_id: 3, in_stock: false, color: "yellow", price: 15, created_at: Time.now}
    ]
  end

  def test_basic
    assert_aggs ({"store_id" => {1 => 1, 2 => 2}}), aggs: [:store_id]
  end

  def test_where
    assert_aggs ({"store_id" => {1 => 1}}), aggs: {store_id: {where: {in_stock: true}}}
  end

  def test_order
    agg = Product.search("Product", aggs: {color: {order: {_key: "desc"}}}).aggs["color"]
    assert_equal ["red", "green", "blue"], agg["buckets"].map { |b| b["key"] }
  end

  def test_field
    assert_aggs ({"store_id" => {1 => 1, 2 => 2}}), aggs: {store_id: {}}
    assert_aggs ({"store_id" => {1 => 1, 2 => 2}}), aggs: {store_id: {field: "store_id"}}
    assert_aggs ({"store_id_new" => {1 => 1, 2 => 2}}), aggs: {store_id_new: {field: "store_id"}}
  end

  def test_min_doc_count
    assert_aggs ({"store_id" => {2 => 2}}), aggs: {store_id: {min_doc_count: 2}}
  end

  def test_script
    expected = {"color" => {"Color: blue" => 1, "Color: green" => 1, "Color: red" => 1}}
    assert_aggs expected, aggs: {color: {script: {source: "'Color: ' + _value"}}}
  end

  def test_no_aggs
    assert_nil Product.search("*").aggs
  end

  def test_limit
    agg = Product.search("Product", aggs: {store_id: {limit: 1}}).aggs["store_id"]
    assert_equal 1, agg["buckets"].size
    # assert_equal 3, agg["doc_count"]
    assert_equal(1, agg["sum_other_doc_count"])
  end

  def test_ranges
    price_ranges = [{to: 10}, {from: 10, to: 20}, {from: 20}]
    agg = Product.search("Product", aggs: {price: {ranges: price_ranges}}).aggs["price"]
    assert_equal 3, agg["buckets"].size
    assert_equal 10.0, agg["buckets"][0]["to"]
    assert_equal 20.0, agg["buckets"][2]["from"]
    assert_equal 1, agg["buckets"][0]["doc_count"]
    assert_equal 0, agg["buckets"][1]["doc_count"]
    assert_equal 2, agg["buckets"][2]["doc_count"]
  end

  def test_date_ranges
    ranges = [{to: 1.day.ago}, {from: 1.day.ago, to: 1.day.from_now}, {from: 1.day.from_now}]
    agg = Product.search("Product", aggs: {created_at: {date_ranges: ranges}}).aggs["created_at"]
    assert_equal 1, agg["buckets"][0]["doc_count"]
    assert_equal 1, agg["buckets"][1]["doc_count"]
    assert_equal 1, agg["buckets"][2]["doc_count"]
  end

  def test_query_where
    assert_aggs ({"store_id" => {1 => 1}}), where: {in_stock: true}, aggs: [:store_id]
  end

  def test_two_wheres
    assert_aggs ({"store_id" => {2 => 1}}), where: {color: "red"}, aggs: {store_id: {where: {in_stock: false}}}
  end

  def test_where_override
    assert_aggs ({"store_id" => {}}), where: {color: "red"}, aggs: {store_id: {where: {in_stock: false, color: "blue"}}}
    assert_aggs ({"store_id" => {2 => 1}}), where: {color: "blue"}, aggs: {store_id: {where: {in_stock: false, color: "red"}}}
  end

  def test_skip
    assert_aggs ({"store_id" => {1 => 1, 2 => 2}}), where: {store_id: 2}, aggs: [:store_id]
  end

  def test_skip_complex
    assert_aggs ({"store_id" => {1 => 1, 2 => 1}}), where: {store_id: 2, price: {gt: 5}}, aggs: [:store_id]
  end

  def test_multiple
    expected = {"store_id" => {1 => 1, 2 => 2}, "color" => {"blue" => 1, "green" => 1, "red" => 1}}
    assert_aggs expected, aggs: [:store_id, :color]
  end

  def test_smart_aggs_false
    assert_aggs ({"store_id" => {2 => 2}}), where: {color: "red"}, aggs: {store_id: {where: {in_stock: false}}}, smart_aggs: false
    assert_aggs ({"store_id" => {2 => 2}}), where: {color: "blue"}, aggs: {store_id: {where: {in_stock: false}}}, smart_aggs: false
  end

  def test_aggs_group_by_date
    store [{name: "Old Product", created_at: 3.years.ago}]
    aggs = {products_per_year: {date_histogram: {field: :created_at, calendar_interval: :year}}}
    products = Product.search("Product", where: {created_at: {lt: Time.now}}, aggs: aggs)
    assert_equal 4, products.aggs["products_per_year"]["buckets"].size
  end

  def test_aggs_with_time_zone
    start_time = Time.at(1529366400)
    store [
      {name: "Opera House Pass", created_at: start_time},
      {name: "London Eye Pass", created_at: start_time + 16.hours},
      {name: "London Tube Pass", created_at: start_time + 16.hours}
    ]

    london_aggs = {products_per_day: {date_histogram: {field: :created_at, calendar_interval: :day, time_zone: "+01:00"}}}
    expected = [
      {"key_as_string" => "2018-06-19T00:00:00.000+01:00", "key" => 1529362800000, "doc_count" => 3}
    ]
    assert_equal expected, Product.search("Pass", aggs: london_aggs).aggs["products_per_day"]["buckets"]

    sydney_aggs = {products_per_day: {date_histogram: {field: :created_at, calendar_interval: :day, time_zone: "+10:00"}}}
    expected = [
      {"key_as_string" => "2018-06-19T00:00:00.000+10:00", "key" => 1529330400000, "doc_count" => 1},
      {"key_as_string" => "2018-06-20T00:00:00.000+10:00", "key" => 1529416800000, "doc_count" => 2}
    ]
    assert_equal expected, Product.search("Pass", aggs: sydney_aggs).aggs["products_per_day"]["buckets"]
  end

  def test_aggs_avg
    products = Product.search("*", aggs: {avg_price: {avg: {field: :price}}})
    assert_equal 16.5, products.aggs["avg_price"]["value"]
  end

  def test_aggs_cardinality
    products = Product.search("*", aggs: {total_stores: {cardinality: {field: :store_id}}})
    assert_equal 3, products.aggs["total_stores"]["value"]
  end

  def test_aggs_min_max
    products = Product.search("*", aggs: {min_price: {min: {field: :price}}, max_price: {max: {field: :price}}})
    assert_equal 5, products.aggs["min_price"]["value"]
    assert_equal 25, products.aggs["max_price"]["value"]
  end

  def test_aggs_sum
    products = Product.search("*", aggs: {sum_price: {sum: {field: :price}}})
    assert_equal 66, products.aggs["sum_price"]["value"]
  end

  def test_body_options
    expected = {"price" => {0.0 => 1, 10.0 => 0, 20.0 => 2}}
    assert_aggs expected, body_options: {aggs: {price: {histogram: {field: :price, interval: 10}}}}
  end

  def test_relation
    assert_aggs ({"store_id" => {1 => 1}}), Product.search("Product").aggs(store_id: {where: {in_stock: true}})
  end

  def test_relation_smart_aggs_false
    assert_aggs ({"store_id" => {2 => 2}}), Product.search("Product").where(color: "red").aggs(store_id: {where: {in_stock: false}}).smart_aggs(false)
  end

  protected

  def assert_aggs(expected, options)
    relation = options.is_a?(Searchkick::Relation) ? options : Product.search("Product", **options)
    assert_equal expected, relation.aggs.to_h { |field, agg| [field, buckets_as_hash(agg)] }
  end

  def buckets_as_hash(agg)
    agg["buckets"].to_h { |v| [v["key"], v["doc_count"]] }
  end
end
