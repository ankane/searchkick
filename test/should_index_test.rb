require_relative "test_helper"

class ShouldIndexTest < Minitest::Test
  def test_basic
    store_names ["INDEX", "DO NOT INDEX"]
    assert_search "index", ["INDEX"]
  end

  def test_default_true
    assert Animal.new.should_index?
  end

  def test_change_to_true
    store_names ["DO NOT INDEX"]
    assert_search "index", []
    product = Product.first
    product.name = "INDEX"
    product.save!
    Product.searchkick_index.refresh
    assert_search "index", ["INDEX"]
  end

  def test_change_to_false
    store_names ["INDEX"]
    assert_search "index", ["INDEX"]
    product = Product.first
    product.name = "DO NOT INDEX"
    product.save!
    Product.searchkick_index.refresh
    assert_search "index", []
  end
end
