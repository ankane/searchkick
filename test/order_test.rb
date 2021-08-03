require_relative "test_helper"

class OrderTest < Minitest::Test
  def test_hash
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product D", "Product C", "Product B", "Product A"], order: {name: :desc}
  end

  def test_string
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product A", "Product B", "Product C", "Product D"], order: "name"
  end

  # TODO no longer map id to _id in Searchkick 5
  # since sorting on _id is deprecated in Elasticsearch
  def test_id
    skip if cequel?

    store_names ["Product A", "Product B"]
    product_a = Product.where(name: "Product A").first
    product_b = Product.where(name: "Product B").first
    _, stderr = capture_io do
      assert_order "product", [product_a, product_b].sort_by { |r| r.id.to_s }.map(&:name), order: {id: :asc}
    end
    unless Searchkick.server_below?("7.6.0")
      assert_match "Loading the fielddata on the _id field is deprecated", stderr
    end
  end

  def test_multiple
    store [
      {name: "Product A", color: "blue", store_id: 1},
      {name: "Product B", color: "red", store_id: 3},
      {name: "Product C", color: "red", store_id: 2}
    ]
    assert_order "product", ["Product A", "Product B", "Product C"], order: {color: :asc, store_id: :desc}
  end

  def test_unmapped_type
    Product.search_index.refresh
    assert_order "product", [], order: {not_mapped: {unmapped_type: "long"}}
  end

  def test_array
    store [{name: "San Francisco", latitude: 37.7833, longitude: -122.4167}]
    assert_order "francisco", ["San Francisco"], order: [{_geo_distance: {location: "0,0"}}]
  end
end
