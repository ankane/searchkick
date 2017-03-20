require_relative "test_helper"

class SqlTest < Minitest::Test
  def test_operator
    store_names ["Honey"]
    assert_search "fresh honey", []
    assert_search "fresh honey", ["Honey"], operator: "or"
  end

  def test_operator_scoring
    store_names ["Big Red Circle", "Big Green Circle", "Small Orange Circle"]
    assert_order "big red circle", ["Big Red Circle", "Big Green Circle", "Small Orange Circle"], operator: "or"
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

  # body_options

  def test_body_options_should_merge_into_body
    query = Product.search("*", body_options: {min_score: 1.0}, execute: false)
    assert_equal 1.0, query.body[:min_score]
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

  def test_load_false_with_includes
    store_names ["Product A"]
    assert_kind_of Hash, Product.search("product", load: false, includes: [:store]).first
  end

  def test_load_false_nested_object
    aisle = {"id" => 1, "name" => "Frozen"}
    store [{name: "Product A", aisle: aisle}]
    assert_equal aisle, Product.search("product", load: false).first.aisle.to_hash
  end

  # select

  def test_select
    store [{name: "Product A", store_id: 1}]
    result = Product.search("product", load: false, select: [:name, :store_id]).first
    assert_equal %w(id name store_id), result.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_equal 1, result.store_id
  end

  def test_select_array
    store [{name: "Product A", user_ids: [1, 2]}]
    result = Product.search("product", load: false, select: [:user_ids]).first
    assert_equal [1, 2], result.user_ids
  end

  def test_select_single_field
    store [{name: "Product A", store_id: 1}]
    result = Product.search("product", load: false, select: :name).first
    assert_equal %w(id name), result.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_nil result.store_id
  end

  def test_select_all
    store [{name: "Product A", user_ids: [1, 2]}]
    hit = Product.search("product", select: true).hits.first
    assert_equal hit["_source"]["name"], "Product A"
    assert_equal hit["_source"]["user_ids"], [1, 2]
  end

  def test_select_none
    store [{name: "Product A", user_ids: [1, 2]}]
    hit = Product.search("product", select: []).hits.first
    assert_nil hit["_source"]
    hit = Product.search("product", select: false).hits.first
    assert_nil hit["_source"]
  end

  def test_select_include
    skip unless elasticsearch_below50?
    store [{name: "Product A", user_ids: [1, 2]}]
    result = Product.search("product", load: false, select: {include: [:name]}).first
    assert_equal %w(id name), result.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_nil result.store_id
  end

  def test_select_exclude
    skip unless elasticsearch_below50?
    store [{name: "Product A", user_ids: [1, 2], store_id: 1}]
    result = Product.search("product", load: false, select: {exclude: [:name]}).first
    assert_nil result.name
    assert_equal [1, 2], result.user_ids
    assert_equal 1, result.store_id
  end

  def test_select_include_and_exclude
    skip unless elasticsearch_below50?
    # let's take this to the next level
    store [{name: "Product A", user_ids: [1, 2], store_id: 1}]
    result = Product.search("product", load: false, select: {include: [:store_id], exclude: [:name]}).first
    assert_equal 1, result.store_id
    assert_nil result.name
    assert_nil result.user_ids
  end

  def test_select_includes
    skip if elasticsearch_below50?
    store [{name: "Product A", user_ids: [1, 2]}]
    result = Product.search("product", load: false, select: {includes: [:name]}).first
    assert_equal %w(id name), result.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_nil result.store_id
  end

  def test_select_excludes
    skip if elasticsearch_below50?
    store [{name: "Product A", user_ids: [1, 2], store_id: 1}]
    result = Product.search("product", load: false, select: {excludes: [:name]}).first
    assert_nil result.name
    assert_equal [1, 2], result.user_ids
    assert_equal 1, result.store_id
  end

  def test_select_include_and_excludes
    skip if elasticsearch_below50?
    # let's take this to the next level
    store [{name: "Product A", user_ids: [1, 2], store_id: 1}]
    result = Product.search("product", load: false, select: {includes: [:store_id], excludes: [:name]}).first
    assert_equal 1, result.store_id
    assert_nil result.name
    assert_nil result.user_ids
  end

  # nested

  def test_nested_search
    store [{name: "Product A", aisle: {"id" => 1, "name" => "Frozen"}}], Speaker
    assert_search "frozen", ["Product A"], {fields: ["aisle.name"]}, Speaker
  end

  # other tests

  def test_includes
    skip unless defined?(ActiveRecord)
    store_names ["Product A"]
    assert Product.search("product", includes: [:store]).first.association(:store).loaded?
  end
end
