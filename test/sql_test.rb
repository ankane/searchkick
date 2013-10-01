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
      {name: "Product B", store_id: 2, in_stock: true, backordered: false, created_at: now - 1, orders_count: 3},
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
    # or
    assert_search "product", ["Product A", "Product B", "Product C"], where: {or: [[{in_stock: true}, {store_id: 3}]]}
    assert_search "product", ["Product A", "Product B", "Product C"], where: {or: [[{orders_count: [2, 4]}, {store_id: [1, 2]}]]}
    assert_search "product", ["Product A", "Product D"], where: {or: [[{orders_count: 1}, {created_at: {gte: now - 1}, backordered: true}]]}
    # array
    assert_search "product", ["Product A"], where: {user_ids: 2}
  end

  def test_where_string
    store [
      {name: "Product A", color: "RED"}
    ]
    assert_search "product", ["Product A"], where: {color: ["RED"]}
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

  def test_order_hash
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product D", "Product C", "Product B", "Product A"], order: {name: :desc}
  end

  def test_order_string
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product A", "Product B", "Product C", "Product D"], order: "name"
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

  def test_include
    store_names ["Product A"]
    assert Product.search("product", include: [:store]).first.association(:store).loaded?
  end

end
