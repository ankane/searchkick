require_relative "test_helper"

class MultiIndicesTest < Minitest::Test
  def test_basic
    store_names ["Product A"]
    store_names ["Product B"], Speaker
    assert_search_multi "product", ["Product A", "Product B"]
  end

  def test_where
    store [{name: "Product A", color: "red"}, {name: "Product B", color: "blue"}]
    store_names ["Product C"], Speaker
    assert_search_multi "product", ["Product A", "Product C"], where: {_or: [{_type: "product", color: "red"}, {_type: "speaker"}]}
  end

  private

  def assert_search_multi(term, expected, options = {})
    options[:index_name] = [Product, Speaker]
    options[:fields] = [:name]
    assert_search(term, expected, options, Searchkick)
  end
end
