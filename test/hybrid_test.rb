require_relative "test_helper"

class HybridTest < Minitest::Test
  def setup
    skip unless Searchkick.knn_support?
    super
  end

  def test_search
    error = assert_raises(ArgumentError) do
      Product.search("product", knn: {field: :embedding, vector: [1, 2, 3]})
    end
    assert_equal "Use Searchkick.multi_search for hybrid search", error.message
  end

  def test_multi_search
    store [
      {name: "The dog is barking", embedding: [1, 2, 0]},
      {name: "The cat is purring", embedding: [1, 0, 0]},
      {name: "The bear is growling", embedding: [1, 2, 3]}
    ]

    keyword_search = Product.search("growling bear")
    semantic_search = Product.search(knn: {field: :embedding, vector: [1, 2, 3]})
    Searchkick.multi_search([keyword_search, semantic_search])

    expected = ["The bear is growling", "The dog is barking", "The cat is purring"]
    assert_equal expected.first(1), keyword_search.map(&:name)
    assert_equal expected, semantic_search.map(&:name)
  end
end
