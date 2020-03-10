require_relative "test_helper"

class NestedTest < Minitest::Test
  def test_basic
    store [
      {name: "Product A", categories: [{name: "bread roll"}, {name: "sausage meat"}]}
    ]
    assert_search "sausage", ["Product A"], fields: ["categories.name"]
    assert_search "sausage roll", [], fields: ["categories.name"]
  end
end
