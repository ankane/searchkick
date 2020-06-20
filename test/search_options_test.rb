require_relative "test_helper"

class SearchOptionsTest < Minitest::Test
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
    # have same score due to dismax
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

  # nested

  def test_nested_search
    store [{name: "Product A", aisle: {"id" => 1, "name" => "Frozen"}}], Speaker
    assert_search "frozen", ["Product A"], {fields: ["aisle.name"]}, Speaker
  end

  # other tests

  def test_includes
    skip unless activerecord?

    store_names ["Product A"]
    assert Product.search("product", includes: [:store]).first.association(:store).loaded?
  end

  def test_model_includes
    skip unless activerecord?

    store_names ["Product A"]
    store_names ["Store A"], Store

    associations = {Product => [:store], Store => [:products]}
    result = Searchkick.search("*", models: [Product, Store], model_includes: associations)

    assert_equal 2, result.length

    result.group_by(&:class).each_pair do |klass, records|
      assert records.first.association(associations[klass].first).loaded?
    end
  end

  def test_scope_results
    skip unless activerecord?

    store_names ["Product A", "Product B"]
    assert_search "product", ["Product A"], scope_results: ->(r) { r.where(name: "Product A") }
  end
end
