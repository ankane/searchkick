require_relative "test_helper"

class SqlTest < Minitest::Test
  def test_limit
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product A", "Product B"], order: {name: :asc}, limit: 2
  end

  def test_no_limit
    names = 20.times.map { |i| "Product #{i}" }
    store_names names
    assert_search "product", names
  end

  def test_offset
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product C", "Product D"], order: {name: :asc}, offset: 2
  end

  def test_pagination
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E", "Product F"]
    products = Product.search("product", order: {name: :asc}, page: 2, per_page: 2, padding: 1)
    assert_equal ["Product D", "Product E"], products.map(&:name)
    assert_equal "product", products.entry_name
    assert_equal 2, products.current_page
    assert_equal 1, products.padding
    assert_equal 2, products.per_page
    assert_equal 2, products.size
    assert_equal 2, products.length
    assert_equal 3, products.total_pages
    assert_equal 6, products.total_count
    assert_equal 6, products.total_entries
    assert_equal 2, products.limit_value
    assert_equal 3, products.offset_value
    assert_equal 3, products.offset
    assert_equal 3, products.next_page
    assert_equal 1, products.previous_page
    assert_equal 1, products.prev_page
    assert !products.first_page?
    assert !products.last_page?
    assert !products.empty?
    assert !products.out_of_range?
    assert products.any?
  end

  def test_pagination_nil_page
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E"]
    products = Product.search("product", order: {name: :asc}, page: nil, per_page: 2)
    assert_equal ["Product A", "Product B"], products.map(&:name)
    assert_equal 1, products.current_page
    assert products.first_page?
  end

  def test_where
    now = Time.now
    store [
      {name: "Product A", store_id: 1, in_stock: true, backordered: true, created_at: now, orders_count: 4, user_ids: [1, 2, 3]},
      {name: "Product B", store_id: 2, in_stock: true, backordered: false, created_at: now - 1, orders_count: 3, user_ids: [1]},
      {name: "Product C", store_id: 3, in_stock: false, backordered: true, created_at: now - 2, orders_count: 2, user_ids: [1, 3]},
      {name: "Product D", store_id: 4, in_stock: false, backordered: false, created_at: now - 3, orders_count: 1}
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
    assert_search "product", ["Product A", "Product C"], where: {user_ids: {all: [1, 3]}}
    assert_search "product", [], where: {user_ids: {all: [1, 2, 3, 4]}}
    # any / nested terms
    assert_search "product", ["Product B", "Product C"], where: {user_ids: {not: [2], in: [1, 3]}}
    # not / exists
    assert_search "product", ["Product D"], where: {user_ids: nil}
    assert_search "product", ["Product A", "Product B", "Product C"], where: {user_ids: {not: nil}}
    assert_search "product", ["Product A", "Product C", "Product D"], where: {user_ids: [3, nil]}
    assert_search "product", ["Product B"], where: {user_ids: {not: [3, nil]}}
  end

  def test_regexp
    store_names ["Product A"]
    assert_search "*", ["Product A"], where: {name: /Pro.+/}
  end

  def test_alternate_regexp
    store_names ["Product A", "Item B"]
    assert_search "*", ["Product A"], where: {name: {regexp: "Pro.+"}}
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
      {name: "Product A", user_ids: [11, 23, 13, 16, 17, 23]},
      {name: "Product B", user_ids: [1, 2, 3, 4, 5, 6, 7, 8, 9]},
      {name: "Product C", user_ids: [101, 230, 150, 200]}
    ]
    assert_search "product", ["Product A"], where: {user_ids: {gt: 10, lt: 24}}
  end

  def test_where_range_array_again
    store [
      {name: "Product A", user_ids: [19, 32, 42]},
      {name: "Product B", user_ids: [13, 40, 52]}
    ]
    assert_search "product", ["Product A"], where: {user_ids: {gt: 26, lt: 36}}
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

  def test_order_ignore_unmapped
    assert_order "product", [], order: {not_mapped: {ignore_unmapped: true}}, conversions: false
  end

  def test_order_array
    store [{name: "San Francisco", latitude: 37.7833, longitude: -122.4167}]
    assert_order "francisco", ["San Francisco"], order: [{_geo_distance: {location: "0,0"}}], conversions: false
  end

  def test_partial
    store_names ["Honey"]
    assert_search "fresh honey", []
    assert_search "fresh honey", ["Honey"], partial: true
  end

  def test_operator
    store_names ["Honey"]
    assert_search "fresh honey", []
    assert_search "fresh honey", ["Honey"], operator: "or"
  end

  def test_misspellings
    store_names ["abc", "abd", "aee"]
    assert_search "abc", ["abc"], misspellings: false
  end

  def test_misspellings_distance
    store_names ["abbb", "aabb"]
    assert_search "aaaa", ["aabb"], misspellings: {distance: 2}
  end

  def test_misspellings_prefix_length
    store_names ["ap", "api", "apt", "any", "nap", "ah", "ahi"]
    assert_search "ap", ["ap"], misspellings: {prefix_length: 2}
    assert_search "api", ["ap", "api", "apt"], misspellings: {prefix_length: 2}
  end

  def test_misspellings_prefix_length_operator
    store_names ["ap", "api", "apt", "any", "nap", "ah", "aha"]
    assert_search "ap ah", ["ap", "ah"], operator: "or", misspellings: {prefix_length: 2}
    assert_search "api ahi", ["ap", "api", "apt", "ah", "aha"], operator: "or", misspellings: {prefix_length: 2}
  end

  def test_misspellings_fields_operator
    store [
      {name: "red", color: "red"},
      {name: "blue", color: "blue"},
      {name: "cyan", color: "blue green"},
      {name: "magenta", color: "red blue"},
      {name: "green", color: "green"}
    ]
    assert_search "red blue", ["red", "blue", "cyan", "magenta"], operator: "or", fields: ["color"], misspellings: false
  end

  def test_fields_operator
    store [
      {name: "red", color: "red"},
      {name: "blue", color: "blue"},
      {name: "cyan", color: "blue green"},
      {name: "magenta", color: "red blue"},
      {name: "green", color: "green"}
    ]
    assert_search "red blue", ["red", "blue", "cyan", "magenta"], operator: "or", fields: ["color"]
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
      {name: "Product", latitude: 80.0}
    ]
    assert_search "product", ["Product"], where: {latitude: {gt: 79}}
  end

  # load

  def test_load_default
    store_names ["Product A"]
    assert_kind_of Product, Product.search("product").first
  end

  def test_load_false
    store_names ["Product A"]
    assert_kind_of Hash, Product.search("product", load: false).first
  end

  def test_load_false_methods
    store_names ["Product A"]
    assert_equal "Product A", Product.search("product", load: false).first.name
  end

  def test_load_false_with_include
    store_names ["Product A"]
    assert_kind_of Hash, Product.search("product", load: false, include: [:store]).first
  end

  # select

  def test_select
    store [{name: "Product A", store_id: 1}]
    result = Product.search("product", load: false, select: [:name, :store_id]).first
    assert_equal %w(id name store_id), result.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal ["Product A"], result.name # this is not great
  end

  def test_select_array
    store [{name: "Product A", user_ids: [1, 2]}]
    result = Product.search("product", load: false, select: [:user_ids]).first
    assert_equal [1, 2], result.user_ids
  end

  def test_select_all
    store [{name: "Product A", user_ids: [1, 2]}]
    hit = Product.search("product", select: true).hits.first
    assert_equal hit["_source"]["name"], "Product A"
    assert_equal hit["_source"]["user_ids"], [1, 2]
  end

  def test_nested_object
    aisle = {"id" => 1, "name" => "Frozen"}
    store [{name: "Product A", aisle: aisle}]
    assert_equal aisle, Product.search("product", load: false).first.aisle.to_hash
  end

  # TODO see if Mongoid is loaded
  unless defined?(Mongoid) || defined?(NoBrainer)
    def test_include
      store_names ["Product A"]
      assert Product.search("product", include: [:store]).first.association(:store).loaded?
    end
  end
end
