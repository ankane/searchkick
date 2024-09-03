require_relative "test_helper"

class HybridTest < Minitest::Test
  def setup
    skip unless Searchkick.knn_support?
    super
  end

  def test_basic
    store [
      {name: "Product A", embedding: [1, 2, 3]},
      {name: "Item B", embedding: [1, 2, 3]},
      {name: "Product C", embedding: [-1, -2, -3]}
    ]
    assert_order "product", ["Product A", "Product C", "Item B"], knn: {field: :embedding, vector: [1, 2, 3]}
  end

  def test_score
    store [
      {name: "The dog is barking", embedding: [1, 2, 0]},
      {name: "The cat is purring", embedding: [1, 0, 0]},
      {name: "The bear is growling", embedding: [1, 2, 3]}
    ]
    expected = ["The bear is growling", "The dog is barking", "The cat is purring"]
    assert_order "growling bear", expected, knn: {field: :embedding, vector: [1, 2, 3]}
    pp Product.search("growling bear", knn: {field: :embedding, vector: [1, 2, 3]}).hits
  end
end
