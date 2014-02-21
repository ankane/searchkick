require_relative "test_helper"

class TestSql < Minitest::Unit::TestCase

  def test_limit
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product A", "Product B"], order: {name: :asc}, limit: 2
  end

  def test_no_limit
    names = 20.times.map{|i| "Product #{i}" }
    store_names names
    assert_search "product", names
  end

  def test_offset
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product C", "Product D"], order: {name: :asc}, offset: 2
  end

  def test_pagination
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E"]
    products = Product.search("product", order: {name: :asc}, page: 2, per_page: 2)
    assert_equal ["Product C", "Product D"], products.map(&:name)
    assert_equal 2, products.current_page
    assert_equal 2, products.per_page
    assert_equal 3, products.total_pages
    assert_equal 5, products.total_count
  end

  def test_pagination_nil_page
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E"]
    products = Product.search("product", order: {name: :asc}, page: nil, per_page: 2)
    assert_equal ["Product A", "Product B"], products.map(&:name)
    assert_equal 1, products.current_page
  end

  def test_where
    now = Time.now
    store [
      {name: "Product A", store_id: 1, in_stock: true, backordered: true, created_at: now, orders_count: 4, user_ids: [1, 2, 3]},
      {name: "Product B", store_id: 2, in_stock: true, backordered: false, created_at: now - 1, orders_count: 3, user_ids: [1]},
      {name: "Product C", store_id: 3, in_stock: false, backordered: true, created_at: now - 2, orders_count: 2},
      {name: "Product D", store_id: 4, in_stock: false, backordered: false, created_at: now - 3, orders_count: 1},
    ]
    assert_search "product", ["Product A", "Product B"], where: {in_stock: true}
    # date
    assert_search "product", ["Product A"], where: {created_at: {gt: now - 1}}
    assert_search "product", ["Product A", "Product B"], where: {created_at: {gte: now - 1}}
    assert_search "product", ["Product D"], where: {created_at: {lt: now - 2}}
    assert_search "product", ["Product C", "Product D"], where: {created_at: {lte: now - 2}}
    # integer
    assert_search "product", ["Product A"], where: {store_id: {lt: 2}}
    assert_search "product", ["Product A", "Product B"], where: {store_id: {lte: 2}}
    assert_search "product", ["Product D"], where: {store_id: {gt: 3}}
    assert_search "product", ["Product C", "Product D"], where: {store_id: {gte: 3}}
    # range
    assert_search "product", ["Product A", "Product B"], where: {store_id: 1..2}
    assert_search "product", ["Product A"], where: {store_id: 1...2}
    assert_search "product", ["Product A", "Product B"], where: {store_id: [1, 2]}
    assert_search "product", ["Product B", "Product C", "Product D"], where: {store_id: {not: 1}}
    assert_search "product", ["Product C", "Product D"], where: {store_id: {not: [1, 2]}}
    assert_search "product", ["Product A"], where: {user_ids: {lte: 2, gte: 2}}
    # or
    assert_search "product", ["Product A", "Product B", "Product C"], where: {or: [[{in_stock: true}, {store_id: 3}]]}
    assert_search "product", ["Product A", "Product B", "Product C"], where: {or: [[{orders_count: [2, 4]}, {store_id: [1, 2]}]]}
    assert_search "product", ["Product A", "Product D"], where: {or: [[{orders_count: 1}, {created_at: {gte: now - 1}, backordered: true}]]}
    # all
    assert_search "product", ["Product A"], where: {user_ids: {all: [1, 3]}}
    assert_search "product", [], where: {user_ids: {all: [1, 2, 3, 4]}}
    # not / exists
    assert_search "product", ["Product C", "Product D"], where: {user_ids: nil}
    assert_search "product", ["Product A", "Product B"], where: {user_ids: {not: nil}}
    assert_search "product", ["Product A", "Product C", "Product D"], where: {user_ids: [3, nil]}
    assert_search "product", ["Product B"], where: {user_ids: {not: [3, nil]}}
  end

  def test_where_string
    store [
      {name: "Product A", color: "RED"}
    ]
    assert_search "product", ["Product A"], where: {color: "RED"}
  end

  def test_where_nil
    store [
      {name: "Product A"},
      {name: "Product B", color: "red"}
    ]
    assert_search "product", ["Product A"], where: {color: nil}
  end

  def test_where_id
    store_names ["Product A"]
    product = Product.last
    assert_search "product", ["Product A"], where: {id: product.id.to_s}
  end

  def test_where_empty
    store_names ["Product A"]
    assert_search "product", ["Product A"], where: {}
  end

  def test_where_empty_array
    store_names ["Product A"]
    assert_search "product", [], where: {store_id: []}
  end

  # http://elasticsearch-users.115913.n3.nabble.com/Numeric-range-quey-or-filter-in-an-array-field-possible-or-not-td4042967.html
  # https://gist.github.com/jprante/7099463
  def test_where_range_array
    store [
      {name: "Product A", user_ids: [11, 23, 13, 16, 17, 23.6]},
      {name: "Product B", user_ids: [1, 2, 3, 4, 5, 6, 7, 8, 8.9, 9.1, 9.4]},
      {name: "Product C", user_ids: [101, 230, 150, 200]}
    ]
    assert_search "product", ["Product A"], where: {user_ids: {gt: 10, lt: 23.9}}
  end

  def test_near
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000}
    ]
    assert_search "san", ["San Francisco"], where: {location: {near: [37.5, -122.5]}}
  end

  def test_near_within
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000},
      {name: "San Marino", latitude: 43.9333, longitude: 12.4667}
    ]
    assert_search "san", ["San Francisco", "San Antonio"], where: {location: {near: [37, -122], within: "2000mi"}}
  end

  def test_top_left_bottom_right
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000}
    ]
    assert_search "san", ["San Francisco"], where: {location: {top_left: [38, -123], bottom_right: [37, -122]}}
  end

  def test_multiple_locations
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000}
    ]
    assert_search "san", ["San Francisco"], where: {multiple_locations: {near: [37.5, -122.5]}}
  end

  def test_order_hash
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product D", "Product C", "Product B", "Product A"], order: {name: :desc}
  end

  def test_order_string
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product A", "Product B", "Product C", "Product D"], order: "name"
  end

  def test_order_id
    store_names ["Product A", "Product B"]
    product_a = Product.where(name: "Product A").first
    product_b = Product.where(name: "Product B").first
    assert_order "product", [product_a, product_b].sort_by(&:id).map(&:name), order: {id: :asc}
  end

  def test_order_multiple
    store [
      {name: "Product A", color: "blue", store_id: 1},
      {name: "Product B", color: "red", store_id: 3},
      {name: "Product C", color: "red", store_id: 2}
    ]
    assert_order "product", ["Product A", "Product B", "Product C"], order: {color: :asc, store_id: :desc}
  end

  def test_partial
    store_names ["Honey"]
    assert_search "fresh honey", []
    assert_search "fresh honey", ["Honey"], partial: true
  end

  def test_misspellings
    store_names ["abc", "abd", "aee"]
    assert_search "abc", ["abc"], misspellings: false
  end

  def test_misspellings_distance
    store_names ["abbb", "aabb"]
    assert_search "aaaa", ["aabb"], misspellings: {distance: 2}
  end

  def test_fields
    store [
      {name: "red", color: "light blue"},
      {name: "blue", color: "red fish"}
    ]
    assert_search "blue", ["red"], fields: ["color"]
  end

  def test_non_existent_field
    store_names ["Milk"]
    assert_search "milk", [], fields: ["not_here"]
  end

  def test_fields_both_match
    store [
      {name: "Blue A", color: "red"},
      {name: "Blue B", color: "light blue"}
    ]
    assert_first "blue", "Blue B", fields: [:name, :color]
  end

  def test_big_decimal
    store [
      {name: "Product", latitude: 100.0}
    ]
    assert_search "product", ["Product"], where: {latitude: {gt: 99}}
  end

  # load

  def test_load_default
    store_names ["Product A"]
    assert_kind_of Product, Product.search("product").first
  end

  def test_load_false
    store_names ["Product A"]
    assert_kind_of Tire::Results::Item, Product.search("product", load: false).first
  end

  def test_load_false_with_include
    store_names ["Product A"]
    assert_kind_of Tire::Results::Item, Product.search("product", load: false, include: [:store]).first
  end

  # TODO see if Mongoid is loaded
  if !defined?(Mongoid)
    def test_include
      store_names ["Product A"]
      assert Product.search("product", include: [:store]).first.association(:store).loaded?
    end
  end

end
