require_relative "test_helper"

class QueryTest < Minitest::Test
  def test_basic
    store_names ["Milk", "Apple"]
    query = Product.search("milk", execute: false)
    # query.body = {query: {match_all: {}}}
    # query.body = {query: {match: {name: "Apple"}}}
    query.body[:query] = {match_all: {}}
    assert_equal ["Apple", "Milk"], query.map(&:name).sort
    assert_equal ["Apple", "Milk"], query.execute.map(&:name).sort
  end

  def test_with_effective_min_score
    store_names ["Milk", "Milk2"]
    assert_search "milk", ["Milk"], body_options: {min_score: 1}
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
end
