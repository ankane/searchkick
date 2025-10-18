require_relative "test_helper"

class OrderTest < Minitest::Test
  def test_hash
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order ["Product D", "Product C", "Product B", "Product A"], search("product", order: {name: :desc})
    assert_order ["Product D", "Product C", "Product B", "Product A"], search("product").order(name: :desc)
  end

  def test_string
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order ["Product A", "Product B", "Product C", "Product D"], search("product", order: "name")
    assert_order ["Product A", "Product B", "Product C", "Product D"], search("product").order("name")
  end

  def test_multiple
    store [
      {name: "Product A", color: "blue", store_id: 1},
      {name: "Product B", color: "red", store_id: 3},
      {name: "Product C", color: "red", store_id: 2}
    ]
    assert_order ["Product A", "Product B", "Product C"], search("product", order: {color: :asc, store_id: :desc})
    assert_order ["Product A", "Product B", "Product C"], search("product").order(color: :asc, store_id: :desc)
    assert_order ["Product A", "Product B", "Product C"], search("product").order(:color, store_id: :desc)
    assert_order ["Product A", "Product B", "Product C"], search("product").order(color: :asc).order(store_id: :desc)
    assert_order ["Product B", "Product C", "Product A"], search("product").order(color: :asc).reorder(store_id: :desc)
  end

  def test_unmapped_type
    Product.searchkick_index.refresh
    assert_order [], search("product", order: {not_mapped: {unmapped_type: "long"}})
    assert_order [], search("product").order(not_mapped: {unmapped_type: "long"})
  end

  def test_array
    store [{name: "San Francisco", latitude: 37.7833, longitude: -122.4167}]
    assert_order ["San Francisco"], search("francisco", order: [{_geo_distance: {location: "0,0"}}])
    assert_order ["San Francisco"], search("francisco").order([{_geo_distance: {location: "0,0"}}])
  end

  def test_script
    store_names ["Red", "Green", "Blue"]
    order = {_script: {type: "number", script: {source: "doc['name'].value.length() * -1"}}}
    assert_order ["Green", "Blue", "Red"], search("*", order: order)
    assert_order ["Green", "Blue", "Red"], search("*").order(order)
  end
end
