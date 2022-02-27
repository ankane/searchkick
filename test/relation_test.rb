require_relative "test_helper"

class RelationTest < Minitest::Test
  def test_loaded
    Product.search_index.refresh
    products = Product.search("*")
    refute products.loaded?
    assert_equal 0, products.count
    assert products.loaded?
    error = assert_raises(Searchkick::Error) do
      products.limit!(2)
    end
    assert_equal "Relation loaded", error.message
  end

  def test_clone
    products = Product.search("*")
    assert_equal 10, products.limit(10).limit_value
    assert_equal 10000, products.limit_value
  end

  def test_only
    assert_equal 10, Product.search("*").limit(10).only(:limit).limit_value
  end

  def test_except
    assert_equal 10000, Product.search("*").limit(10).except(:limit).limit_value
  end
end
