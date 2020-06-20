require_relative "test_helper"

class SelectTest < Minitest::Test
  def test_basic
    store [{name: "Product A", store_id: 1}]
    result = Product.search("product", load: false, select: [:name, :store_id]).first
    assert_equal %w(id name store_id), result.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_equal 1, result.store_id
  end

  def test_array
    store [{name: "Product A", user_ids: [1, 2]}]
    result = Product.search("product", load: false, select: [:user_ids]).first
    assert_equal [1, 2], result.user_ids
  end

  def test_single_field
    store [{name: "Product A", store_id: 1}]
    result = Product.search("product", load: false, select: :name).first
    assert_equal %w(id name), result.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_nil result.store_id
  end

  def test_all
    store [{name: "Product A", user_ids: [1, 2]}]
    hit = Product.search("product", select: true).hits.first
    assert_equal hit["_source"]["name"], "Product A"
    assert_equal hit["_source"]["user_ids"], [1, 2]
  end

  def test_none
    store [{name: "Product A", user_ids: [1, 2]}]
    hit = Product.search("product", select: []).hits.first
    assert_nil hit["_source"]
    hit = Product.search("product", select: false).hits.first
    assert_nil hit["_source"]
  end

  def test_includes
    store [{name: "Product A", user_ids: [1, 2]}]
    result = Product.search("product", load: false, select: {includes: [:name]}).first
    assert_equal %w(id name), result.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_nil result.store_id
  end

  def test_excludes
    store [{name: "Product A", user_ids: [1, 2], store_id: 1}]
    result = Product.search("product", load: false, select: {excludes: [:name]}).first
    assert_nil result.name
    assert_equal [1, 2], result.user_ids
    assert_equal 1, result.store_id
  end

  def test_include_and_excludes
    # let's take this to the next level
    store [{name: "Product A", user_ids: [1, 2], store_id: 1}]
    result = Product.search("product", load: false, select: {includes: [:store_id], excludes: [:name]}).first
    assert_equal 1, result.store_id
    assert_nil result.name
    assert_nil result.user_ids
  end
end
