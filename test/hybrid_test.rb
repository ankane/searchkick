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
    assert_order "product", ["Product A", "Product C"], knn: {field: :embedding, vector: [1, 2, 3]}
  end
end
