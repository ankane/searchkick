require_relative "test_helper"

class QueryTest < Minitest::Test
  def test_basic
    store_names ["Milk", "Apple"]
    query = Product.search("milk", execute: false)
    query.body[:query] = {match_all: {}}
    assert_equal ["Apple", "Milk"], query.map(&:name).sort
    assert_equal ["Apple", "Milk"], query.execute.map(&:name).sort
  end

  def test_with_uneffective_min_score
    store_names ["Milk", "Milk2"]
    assert_search "milk", ["Milk", "Milk2"], body_options: {min_score: 0.0001}
  end

  def test_default_timeout
    assert_equal "6s", Product.search("*", execute: false).body[:timeout]
  end

  def test_timeout_override
    assert_equal "1s", Product.search("*", body_options: {timeout: "1s"}, execute: false).body[:timeout]
  end

  def test_request_params
    assert_equal "dfs_query_then_fetch", Product.search("*", request_params: {search_type: "dfs_query_then_fetch"}, execute: false).params[:search_type]
  end

  def test_debug
    store_names ["Milk"]
    out, _ = capture_io do
      assert_search "milk", ["Milk"], debug: true
    end
    refute_includes out, "Error"
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
    assert_warns "Records in search index do not exist in database" do
      assert_search "product", ["Product A"], scope_results: ->(r) { r.where(name: "Product A") }
    end
  end
end
