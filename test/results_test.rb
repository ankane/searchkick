require_relative "test_helper"

class ResultsTest < Minitest::Test
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
end
