require_relative "test_helper"

class KnnTest < Minitest::Test
  def setup
    skip unless Searchkick.knn_support?
    super
  end

  def test_basic
    store [{name: "A", embedding: [1, 2, 3]}, {name: "B", embedding: [-1, -2, -3]}, {name: "C"}]
    assert_order "*", ["A", "B"], knn: {field: :embedding, vector: [1, 2, 3]}

    scores = Product.search(knn: {field: :embedding, vector: [1, 2, 3]}).hits.map { |v| v["_score"] }
    assert_in_delta 1, scores[0]
    assert_in_delta 0, scores[1]
  end

  def test_basic_exact
    store [{name: "A", embedding: [1, 2, 3]}, {name: "B", embedding: [-1, -2, -3]}, {name: "C"}]
    assert_order "*", ["A", "B"], knn: {field: :embedding, vector: [1, 2, 3], exact: true}

    scores = Product.search(knn: {field: :embedding, vector: [1, 2, 3], exact: true}).hits.map { |v| v["_score"] }
    assert_in_delta 1, scores[0]
    assert_in_delta 0, scores[1]
  end

  def test_where
    store [
      {name: "A", store_id: 1, embedding: [1, 2, 3]},
      {name: "B", store_id: 2, embedding: [1, 2, 3]},
      {name: "C", store_id: 1, embedding: [-1, -2, -3]},
      {name: "D", store_id: 1}
    ]
    assert_order "*", ["A", "C"], knn: {field: :embedding, vector: [1, 2, 3]}, where: {store_id: 1}
  end

  def test_where_exact
    store [
      {name: "A", store_id: 1, embedding: [1, 2, 3]},
      {name: "B", store_id: 2, embedding: [1, 2, 3]},
      {name: "C", store_id: 1, embedding: [-1, -2, -3]},
      {name: "D", store_id: 1}
    ]
    assert_order "*", ["A", "C"], knn: {field: :embedding, vector: [1, 2, 3], exact: true}, where: {store_id: 1}
  end

  def test_pagination
    store [
      {name: "A", embedding: [1, 2, 3]},
      {name: "B", embedding: [1, 2, 0]},
      {name: "C", embedding: [-1, -2, 0]},
      {name: "D", embedding: [-1, -2, -3]},
      {name: "E"}
    ]
    assert_order "*", ["B", "C"], knn: {field: :embedding, vector: [1, 2, 3]}, limit: 2, offset: 1
  end

  def test_pagination_exact
    store [
      {name: "A", embedding: [1, 2, 3]},
      {name: "B", embedding: [1, 2, 0]},
      {name: "C", embedding: [-1, -2, 0]},
      {name: "D", embedding: [-1, -2, -3]},
      {name: "E"}
    ]
    assert_order "*", ["B", "C"], knn: {field: :embedding, vector: [1, 2, 3], exact: true}, limit: 2, offset: 1
  end

  def test_euclidean
    store [{name: "A", factors: [1, 2, 3]}, {name: "B", factors: [1, 5, 7]}, {name: "C"}]
    assert_order "*", ["A", "B"], knn: {field: :factors, vector: [1, 2, 3]}

    scores = Product.search(knn: {field: :factors, vector: [1, 2, 3]}).hits.map { |v| v["_score"] }
    assert_in_delta 1.0 / (1 + 0), scores[0]
    assert_in_delta 1.0 / (1 + 5**2), scores[1]
  end

  def test_euclidean_exact
    store [{name: "A", embedding: [1, 2, 3]}, {name: "B", embedding: [1, 5, 7]}, {name: "C"}]
    assert_order "*", ["A", "B"], knn: {field: :embedding, vector: [1, 2, 3], distance: "euclidean"}

    scores = Product.search(knn: {field: :embedding, vector: [1, 2, 3], distance: "euclidean"}).hits.map { |v| v["_score"] }
    assert_in_delta 1.0 / (1 + 0), scores[0]
    assert_in_delta 1.0 / (1 + 5**2), scores[1]
  end

  def test_taxicab_exact
    store [{name: "A", embedding: [1, 2, 3]}, {name: "B", embedding: [1, 5, 7]}, {name: "C"}]
    assert_order "*", ["A", "B"], knn: {field: :embedding, vector: [1, 2, 3], distance: "taxicab"}

    scores = Product.search(knn: {field: :embedding, vector: [1, 2, 3], distance: "taxicab"}).hits.map { |v| v["_score"] }
    assert_in_delta 1.0 / (1 + 0), scores[0]
    assert_in_delta 1.0 / (1 + 7), scores[1]
  end

  def test_chebyshev_exact
    skip unless Searchkick.opensearch?

    store [{name: "A", embedding: [1, 2, 3]}, {name: "B", embedding: [1, 5, 7]}, {name: "C"}]
    assert_order "*", ["A", "B"], knn: {field: :embedding, vector: [1, 2, 3], distance: "chebyshev"}

    scores = Product.search(knn: {field: :embedding, vector: [1, 2, 3], distance: "chebyshev"}).hits.map { |v| v["_score"] }
    assert_in_delta 1.0 / (1 + 0), scores[0]
    assert_in_delta 1.0 / (1 + 4), scores[1]
  end

  def test_inner_product
    store [{name: "A", embedding2: [-1, -2, -3]}, {name: "B", embedding2: [1, 5, 7]}, {name: "C"}]
    assert_order "*", ["B", "A"], knn: {field: :embedding2, vector: [1, 2, 3], distance: "inner_product"}

    scores = Product.search(knn: {field: :embedding2, vector: [1, 2, 3], distance: "inner_product"}).hits.map { |v| v["_score"] }
    # d > 0: d + 1
    # else: 1 / (1 - d)
    assert_in_delta 1 + 32, scores[0], (!Searchkick.opensearch? ? 0.5 : 0.001)
    assert_in_delta 1.0 / (1 + 14), scores[1]
  end

  def test_inner_product_exact
    store [{name: "A", embedding: [-1, -2, -3]}, {name: "B", embedding: [1, 5, 7]}, {name: "C"}]
    assert_order "*", ["B", "A"], knn: {field: :embedding, vector: [1, 2, 3], distance: "inner_product"}

    scores = Product.search(knn: {field: :embedding, vector: [1, 2, 3], distance: "inner_product"}).hits.map { |v| v["_score"] }
    assert_in_delta 1 + 32, scores[0]
    assert_in_delta 1.0 / (1 + 14), scores[1]
  end

  def test_unindexed
    skip if Searchkick.opensearch?

    store [{name: "A", vector: [1, 2, 3]}, {name: "B", vector: [-1, -2, -3]}, {name: "C"}]
    assert_order "*", ["A", "B"], knn: {field: :vector, vector: [1, 2, 3], distance: "cosine"}

    scores = Product.search(knn: {field: :vector, vector: [1, 2, 3], distance: "cosine"}).hits.map { |v| v["_score"] }
    assert_in_delta 1, scores[0]
    assert_in_delta 0, scores[1]

    error = assert_raises(ArgumentError) do
      Product.search(knn: {field: :vector, vector: [1, 2, 3]})
    end
    assert_match "distance required", error.message

    error = assert_raises(ArgumentError) do
      Product.search(knn: {field: :vector, vector: [1, 2, 3], exact: false})
    end
    assert_match "distance required", error.message

    error = assert_raises(ArgumentError) do
      Product.search(knn: {field: :embedding, vector: [1, 2, 3], distance: "euclidean", exact: false})
    end
    assert_equal "distance must match searchkick options for approximate search", error.message
  end

  def test_explain
    store [{name: "A", embedding: [1, 2, 3], factors: [1, 2, 3], vector: [1, 2, 3], embedding2: [1, 2, 3]}]

    assert_approx true, :embedding, "cosine"
    assert_approx false, :embedding, "euclidean"
    assert_approx false, :embedding, "inner_product"
    assert_approx false, :embedding, "taxicab"

    if Searchkick.opensearch?
      assert_approx false, :embedding, "chebyshev"
    end

    assert_approx false, :factors, "cosine"
    assert_approx true, :factors, "euclidean"
    assert_approx false, :factors, "inner_product"

    unless Searchkick.opensearch?
      assert_approx false, :vector, "cosine"
      assert_approx false, :vector, "euclidean"
      assert_approx false, :vector, "inner_product"
    end

    assert_approx false, :embedding2, "cosine"
    assert_approx false, :embedding2, "euclidean"
    assert_approx true, :embedding2, "inner_product"

    assert_approx false, :embedding, "cosine", exact: true
    assert_approx true, :embedding, "cosine", exact: false

    error = assert_raises(ArgumentError) do
      assert_approx true, :embedding, "euclidean", exact: false
    end
    assert_equal "distance must match searchkick options for approximate search", error.message
  end

  private

  def assert_approx(approx, field, distance, **knn_options)
    response = Product.search(knn: {field: field, vector: [1, 2, 3], distance: distance, **knn_options}, explain: true).response.to_s
    if approx
      if Searchkick.opensearch?
        assert_match "within top", response
      else
        assert_match "within top k documents", response
      end
    else
      if Searchkick.opensearch?
        assert_match "knn_score", response
      else
        assert_match "params.query_vector", response
      end
    end
  end
end
