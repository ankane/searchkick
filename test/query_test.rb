require_relative "test_helper"

class TestQuery < Minitest::Test

  def test_basic
    store_names ["Milk", "Apple"]
    query = Product.search("milk", execute: false)
    # query.body = {query: {match_all: {}}}
    # query.body = {query: {match: {name: "Apple"}}}
    query.body[:query] = {match_all: {}}
    assert_equal ["Apple", "Milk"], query.execute.map(&:name).sort
  end

  def test_query_cache_true
    query = Searchkick::Query.new(Product, "*", query_cache: true)

    params = query.params

    assert params[:query_cache]
  end

  def test_query_cache_false
    query = Searchkick::Query.new(Product, "*", query_cache: false)
    params = query.params

    refute params[:query_cache]
  end

  def test_query_cache_nil
    # query_cache given as nil
    query = Searchkick::Query.new(Product, "*", query_cache: nil)
    assert_nil query.params[:query_cache]

    # query_cache given as non boolean
    query = Searchkick::Query.new(Product, "*", query_cache: "non boolean value")
    assert_nil query.params[:query_cache]

    # query_cache not given
    query = Searchkick::Query.new(Product, "*")
    assert_nil query.params[:query_cache]
  end
end
