require_relative "test_helper"

class KnnTest < Minitest::Test
  def setup
    skip unless Searchkick.knn_support?
    super
  end

  def test_basic
    store [{name: "A", embedding: [1, 2, 3]}, {name: "B", embedding: [-1, -2, -3]}]
    assert_order "*", ["A", "B"], knn: {field: :embedding, vector: [1, 2, 3]}

    scores = Product.search(knn: {field: :embedding, vector: [1, 2, 3]}).hits.map { |v| v["_score"] }
    assert_in_delta 1, scores[0]
    assert_in_delta 0, scores[1]
  end

  def test_where
    store [
      {name: "A", store_id: 1, embedding: [1, 2, 3]},
      {name: "B", store_id: 2, embedding: [1, 2, 3]},
      {name: "C", store_id: 1, embedding: [-1, -2, -3]},
    ]
    assert_order "*", ["A", "C"], knn: {field: :embedding, vector: [1, 2, 3]}, where: {store_id: 1}
  end

  def test_pagination
    store [
      {name: "A", embedding: [1, 2, 3]},
      {name: "B", embedding: [1, 2, 0]},
      {name: "C", embedding: [-1, -2, 0]},
      {name: "D", embedding: [-1, -2, -3]}
    ]
    assert_order "*", ["B", "C"], knn: {field: :embedding, vector: [1, 2, 3]}, limit: 2, offset: 1
  end

  def test_exact_cosine
    store [{name: "A", embedding: [1, 2, 3]}, {name: "B", embedding: [-1, -2, -3]}]
    assert_order "*", ["A", "B"], knn: {field: :embedding, vector: [1, 2, 3], exact: true}

    scores = Product.search(knn: {field: :embedding, vector: [1, 2, 3], exact: true}).hits.map { |v| v["_score"] }
    # TODO match approximate
    assert_in_delta 2, scores[0]
    assert_in_delta 0, scores[1]
  end

  def test_exact_euclidean
    store [{name: "A", embedding: [1, 2, 3]}, {name: "B", embedding: [1, 5, 7]}]
    assert_order "*", ["A", "B"], knn: {field: :embedding, vector: [1, 2, 3], exact: true, distance: "euclidean"}

    scores = Product.search(knn: {field: :embedding, vector: [1, 2, 3], exact: true, distance: "euclidean"}).hits.map { |v| v["_score"] }
    # TODO return distance
    assert_in_delta 1.0 / (1 + 0), scores[0]
    if Searchkick.opensearch?
      assert_in_delta 1.0 / (1 + 5**2), scores[1]
    else
      assert_in_delta 1.0 / (1 + 5), scores[1]
    end
  end

  def test_distance
    error = assert_raises(ArgumentError) do
      Product.search(knn: {field: :embedding, vector: [1, 2, 3], distance: "cosine"})
    end
    assert_equal "distance must be set on index for approximate search", error.message
  end
end
