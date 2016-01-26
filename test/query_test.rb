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

  def test_records_with_active_record_model
    store_names ["Milk", "Apple"]
    query = Product.search("milk", active_record_model: ProductWithDeleted, execute: false)

    assert_equal ProductWithDeleted, query.execute.first.class
  end
end
