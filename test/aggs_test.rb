require_relative "test_helper"

class AggsTest < Minitest::Test
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
    assert_equal ({1 => 1, 2 => 2}), store_agg(aggs: [:store_id])
  end

  def test_where
    assert_equal ({1 => 1}), store_agg(aggs: {store_id: {where: {in_stock: true}}})
  end

  def test_order
    agg = Product.search("Product", aggs: {color: {order: {"_term" => "desc"}}}).aggs["color"]
    assert_equal %w(red green blue), agg["buckets"].map { |b| b["key"] }
  end

  def test_field
    assert_equal ({1 => 1, 2 => 2}), store_agg(aggs: {store_id: {}})
    assert_equal ({1 => 1, 2 => 2}), store_agg(aggs: {store_id: {field: "store_id"}})
    assert_equal ({1 => 1, 2 => 2}), store_agg({aggs: {store_id_new: {field: "store_id"}}}, "store_id_new")
  end

  def test_min_doc_count
    assert_equal ({2 => 2}), store_agg(aggs: {store_id: {min_doc_count: 2}})
  end

  def test_no_aggs
    assert_nil Product.search("*").aggs
  end

  def test_limit
    agg = Product.search("Product", aggs: {store_id: {limit: 1}}).aggs["store_id"]
    assert_equal 1, agg["buckets"].size
    # assert_equal 3, agg["doc_count"]
    assert_equal(1, agg["sum_other_doc_count"]) unless Searchkick.server_below?("1.4.0")
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
    assert_equal ({1 => 1}), store_agg(where: {in_stock: true}, aggs: [:store_id])
  end

  def test_two_wheres
    assert_equal ({2 => 1}), store_agg(where: {color: "red"}, aggs: {store_id: {where: {in_stock: false}}})
  end

  def test_where_override
    assert_equal ({}), store_agg(where: {color: "red"}, aggs: {store_id: {where: {in_stock: false, color: "blue"}}})
    assert_equal ({2 => 1}), store_agg(where: {color: "blue"}, aggs: {store_id: {where: {in_stock: false, color: "red"}}})
  end

  def test_skip
    assert_equal ({1 => 1, 2 => 2}), store_agg(where: {store_id: 2}, aggs: [:store_id])
  end

  def test_skip_complex
    assert_equal ({1 => 1, 2 => 1}), store_agg(where: {store_id: 2, price: {gt: 5}}, aggs: [:store_id])
  end

  def test_multiple
    assert_equal ({"store_id" => {1 => 1, 2 => 2}, "color" => {"blue" => 1, "green" => 1, "red" => 1}}), store_multiple_aggs(aggs: [:store_id, :color])
  end

  def test_smart_aggs_false
    assert_equal ({2 => 2}), store_agg(where: {color: "red"}, aggs: {store_id: {where: {in_stock: false}}}, smart_aggs: false)
    assert_equal ({2 => 2}), store_agg(where: {color: "blue"}, aggs: {store_id: {where: {in_stock: false}}}, smart_aggs: false)
  end

  def test_aggs_group_by_date
    store [{name: "Old Product", created_at: 3.years.ago}]
    aggs = Product.search(
      "Product",
              aggs: {
                products_per_year: {
                  date_histogram: {
                    field: :created_at,
                    interval: :year
                  }
                }
              }
    ).aggs

    if elasticsearch_below20?
      assert_equal 2, aggs["products_per_year"]["buckets"].size
    else
      assert_equal 4, aggs["products_per_year"]["buckets"].size
    end
  end

  protected

  def buckets_as_hash(agg)
    Hash[agg["buckets"].map { |v| [v["key"], v["doc_count"]] }]
  end

  def store_agg(options, agg_key = "store_id")
    buckets = Product.search("Product", options).aggs[agg_key]
    buckets_as_hash(buckets)
  end

  def store_multiple_aggs(options)
    Hash[Product.search("Product", options).aggs.map do |field, filtered_agg|
      [field, buckets_as_hash(filtered_agg)]
    end]
  end
end
