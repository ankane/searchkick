require_relative "test_helper"

class RoutingTest < Minitest::Test
  def test_routing_query
    query = Store.search("Dollar Tree", routing: "Dollar Tree", execute: false)
    assert_equal query.params[:routing], "Dollar Tree"
  end

  def test_routing_mappings
    index_options = Store.searchkick_index.index_options
    assert_equal index_options[:mappings][:_default_][:_routing], required: true
  end
end
