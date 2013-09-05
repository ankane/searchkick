require_relative "test_helper"

class TestMisspelling < Minitest::Unit::TestCase
  def test_search_strict
    store_names ["abc", "abd", "aee"]
    assert_search_strict "abc", ["abc"], misspelling: false
  end

  def assert_search_strict(term, expected, options = {})
    assert_equal expected.sort, Product.search(term, options).map(&:name).sort
  end
end