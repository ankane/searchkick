require_relative "test_helper"

class LoadTest < Minitest::Test
  def test_default
    store_names ["Product A"]
    assert_kind_of Product, Product.search("product").first
  end

  def test_false
    store_names ["Product A"]
    assert_kind_of Searchkick::HashWrapper, Product.search("product", load: false).first
  end

  def test_false_methods
    store_names ["Product A"]
    assert_equal "Product A", Product.search("product", load: false).first.name
  end

  def test_false_with_includes
    store_names ["Product A"]
    assert_kind_of Searchkick::HashWrapper, Product.search("product", load: false, includes: [:store]).first
  end

  def test_false_nested_object
    aisle = {"id" => 1, "name" => "Frozen"}
    store [{name: "Product A", aisle: aisle}]
    assert_equal aisle, Product.search("product", load: false).first.aisle.to_hash
  end
end
