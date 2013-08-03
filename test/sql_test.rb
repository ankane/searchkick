require_relative "test_helper"

class TestSql < Minitest::Unit::TestCase

  def test_limit
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_search "product", ["Product A", "Product B"], order: {name: :asc}, limit: 2
  end

  def test_offset
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_search "product", ["Product C", "Product D"], order: {name: :asc}, offset: 2
  end

  def test_pagination
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E"]
    assert_search "product", ["Product C", "Product D"], order: {name: :asc}, page: 2, per_page: 2
  end

  def test_pagination_nil_page
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E"]
    assert_search "product", ["Product A", "Product B"], order: {name: :asc}, page: nil, per_page: 2
  end

  def test_where
    now = Time.now
    store [
      {name: "Product A", store_id: 1, in_stock: true, backordered: true, created_at: now, orders_count: 4},
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
    assert_search "product", ["Product A", "Product B", "Product C"], where: {or: [[{in_stock: true}, {store_id: 3}]]}
  end

  def test_where_string
    store [
      {name: "Product A", color: "RED"}
    ]
    assert_search "product", ["Product A"], where: {color: ["RED"]}
  end

  def test_order_hash
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_search "product", ["Product D", "Product C", "Product B", "Product A"], order: {name: :desc}
  end

  def test_order_string
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_search "product", ["Product A", "Product B", "Product C", "Product D"], order: "name"
  end

  def test_partial
    store_names ["Honey"]
    assert_search "fresh honey", []
    assert_search "fresh honey", ["Honey"], partial: true
  end

  def test_fields
    store [
      {name: "red", color: "blue"},
      {name: "blue", color: "red"}
    ]
    assert_search "blue", ["red"], fields: ["color"]
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
    assert_kind_of Tire::Results::Item, Product.search("product", load: false, include: [:brand]).first
  end

  # TODO
  # :include option
end
