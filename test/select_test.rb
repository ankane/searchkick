require_relative "test_helper"

class SelectTest < Minitest::Test
  def test_basic
    store [{name: "Product A", store_id: 1}]
    result = Product.search("product", load: false, select: [:name, :store_id]).first
    assert_equal %w(id name store_id), result.to_h.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_equal 1, result.store_id
  end

  def test_relation
    store [{name: "Product A", store_id: 1}]
    result = Product.search("product", load: false).select(:name, :store_id).first
    assert_equal %w(id name store_id), result.to_h.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_equal 1, result.store_id
  end

  def test_block
    store [{name: "Product A", store_id: 1}, {name: "Product B", store_id: 2}]
    assert_equal ["Product B"], Product.search("product", load: false).select { |v| v.store_id == 2 }.map(&:name)
  end

  def test_block_arguments
    store [{name: "Product A", store_id: 1}, {name: "Product B", store_id: 2}]
    error = assert_raises(ArgumentError) do
      Product.search("product", load: false).select(:name) { |v| v.store_id == 2 }
    end
    assert_equal "wrong number of arguments (given 1, expected 0)", error.message
  end
  def test_multiple
    store [{name: "Product A", store_id: 1}]
    result = Product.search("product", load: false).select(:name).select(:store_id).first
    assert_equal %w(id name store_id), result.to_h.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    assert_equal 1, result.store_id
  end

  def test_reselect
    store [{name: "Product A", store_id: 1}]
    result = Product.search("product", load: false).select(:name).reselect(:store_id).first
    assert_equal %w(id store_id), result.to_h.keys.reject { |k| k.start_with?("_") }.sort
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
    assert_equal %w(id name), result.to_h.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    refute result.respond_to?(:store_id)
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
    assert_equal %w(id name), result.to_h.keys.reject { |k| k.start_with?("_") }.sort
    assert_equal "Product A", result.name
    refute result.respond_to?(:store_id)
  end

  def test_excludes
    store [{name: "Product A", user_ids: [1, 2], store_id: 1}]
    result = Product.search("product", load: false, select: {excludes: [:name]}).first
    refute result.respond_to?(:name)
    assert_equal [1, 2], result.user_ids
    assert_equal 1, result.store_id
  end

  def test_include_and_excludes
    # let's take this to the next level
    store [{name: "Product A", user_ids: [1, 2], store_id: 1}]
    result = Product.search("product", load: false, select: {includes: [:store_id], excludes: [:name]}).first
    assert_equal 1, result.store_id
    refute result.respond_to?(:name)
    refute result.respond_to?(:user_ids)
  end
end
