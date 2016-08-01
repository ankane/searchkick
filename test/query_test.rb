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
    assert_equal ["Milk"], Product.search("Milk", body_options: { min_score: 0.1 }).map(&:name)
  end

  def test_with_uneffective_min_score
    store_names ["Milk", "Milk2"]
    assert_equal ["Milk", "Milk2"], Product.search("Milk", body_options: { min_score: 0.0001 }).map(&:name)
  end
end
