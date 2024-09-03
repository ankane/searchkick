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

    results = Searchkick::Reranking.rrf(keyword_search, semantic_search)
    expected = ["The bear is growling", "The dog is barking", "The cat is purring"]
    assert_equal expected, results.map { |v| v[:result].name }
    assert_in_delta 0.03279, results[0][:score]
    assert_in_delta 0.01612, results[1][:score]
    assert_in_delta 0.01587, results[2][:score]
  end
end
