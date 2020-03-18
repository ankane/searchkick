require_relative "test_helper"

class OrderTest < Minitest::Test
  def test_order_hash
    store_names ["Product A", "Product B", "Product C", "Product D"]
    expected = ["Product D", "Product C", "Product B", "Product A"]
    assert_order "product", expected, order: {name: :desc}
    assert_equal expected, Product.search("product").order(name: :desc).map(&:name)
  end

  def test_order_string
    store_names ["Product A", "Product B", "Product C", "Product D"]
    expected = ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", expected, order: "name"
    assert_equal expected, Product.search("product").order("name").map(&:name)
  end

  def test_order_id
    skip if cequel?

    store_names ["Product A", "Product B"]
    product_a = Product.where(name: "Product A").first
    product_b = Product.where(name: "Product B").first
    expected = [product_a, product_b].sort_by { |r| r.id.to_s }.map(&:name)
    assert_order "product", expected, order: {id: :asc}
    # TODO fix in query?
    # assert_equal expected, Product.search("product").order(id: :asc).map(&:name)
  end

  def test_order_multiple
    store [
      {name: "Product A", color: "blue", store_id: 1},
      {name: "Product B", color: "red", store_id: 3},
      {name: "Product C", color: "red", store_id: 2}
    ]
    expected = ["Product A", "Product B", "Product C"]
    assert_order "product", expected, order: {color: :asc, store_id: :desc}
    assert_equal expected, Product.search("product").order(:color).order(store_id: :desc).map(&:name)
  end

  def test_order_unmapped_type
    assert_order "product", [], order: {not_mapped: {unmapped_type: "long"}}
    assert_search_relation [], Product.search("product").order(not_mapped: {unmapped_type: "long"})
  end

  def test_order_array
    store [{name: "San Francisco", latitude: 37.7833, longitude: -122.4167}]
    assert_order "francisco", ["San Francisco"], order: [{_geo_distance: {location: "0,0"}}]
  end
end
