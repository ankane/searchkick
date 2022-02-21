require_relative "test_helper"

class ResultsTest < Minitest::Test
  def test_array_methods
    store_names ["Product A", "Product B"]
    products = Product.search("product")
    assert_equal 2, products.count
    assert_equal 2, products.size
    assert_equal 2, products.length
    assert products.any?
    refute products.empty?
    refute products.none?
    refute products.one?
    assert products.many?
    assert_kind_of Product, products[0]
    assert_kind_of Array, products.slice(0, 1)
    assert_kind_of Array, products.to_ary
  end

  def test_with_hit
    store_names ["Product A", "Product B"]
    results = Product.search("product")
    assert_kind_of Enumerator, results.with_hit
    assert_equal 2, results.with_hit.to_a.size
    count = 0
    results.with_hit do |product, hit|
      assert_kind_of Product, product
      assert_kind_of Hash, hit
      count += 1
    end
    assert_equal 2, count
  end

  def test_with_score
    store_names ["Product A", "Product B"]
    results = Product.search("product")
    assert_kind_of Enumerator, results.with_score
    assert_equal 2, results.with_score.to_a.size
    count = 0
    results.with_score do |product, score|
      assert_kind_of Product, product
      assert_kind_of Numeric, score
      count += 1
    end
    assert_equal 2, count
  end

  def test_model_name_with_model
    store_names ["Product A", "Product B"]
    results = Product.search("product")
    assert_equal "Product", results.model_name.human
  end

  def test_model_name_without_model
    store_names ["Product A", "Product B"]
    results = Searchkick.search("product")
    assert_equal "Result", results.model_name.human
  end
end
