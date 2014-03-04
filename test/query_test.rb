require_relative "test_helper"

class TestQuery < Minitest::Unit::TestCase

  def test_basic
    store_names ["Milk", "Apple"]
    query = Product.search("milk", execute: false)
    # query.body = {query: {match_all: {}}}
    # query.body = {query: {match: {name: "Apple"}}}
    query.body[:query] = {match_all: {}}
    assert_equal ["Apple", "Milk"], query.execute.map(&:name).sort
  end

end
