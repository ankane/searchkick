require_relative "test_helper"

class ParametersTest < Minitest::Test
  def setup
    require "action_controller"
    super
  end

  def test_options
    params = ActionController::Parameters.new({store_id: 1})
    assert_raises(ActionController::UnfilteredParameters) do
      Product.search("*", **params)
    end
  end

  def test_where
    params = ActionController::Parameters.new({store_id: 1})
    assert_raises(ActionController::UnfilteredParameters) do
      Product.search("*", where: params)
    end
  end

  def test_where_relation
    params = ActionController::Parameters.new({store_id: 1})
    assert_raises(ActionController::UnfilteredParameters) do
      Product.search("*").where(params)
    end
  end

  def test_rewhere_relation
    params = ActionController::Parameters.new({store_id: 1})
    assert_raises(ActionController::UnfilteredParameters) do
      Product.search("*").where(params)
    end
  end

  def test_where_permitted
    store [{name: "Product A", store_id: 1}, {name: "Product B", store_id: 2}]
    params = ActionController::Parameters.new({store_id: 1})
    assert_search "product", ["Product A"], where: params.permit(:store_id)
  end

  def test_where_permitted_relation
    store [{name: "Product A", store_id: 1}, {name: "Product B", store_id: 2}]
    params = ActionController::Parameters.new({store_id: 1})
    assert_search_relation ["Product A"], Product.search("product").where(params.permit(:store_id))
  end

  def test_rewhere_permitted_relation
    store [{name: "Product A", store_id: 1}, {name: "Product B", store_id: 2}]
    params = ActionController::Parameters.new({store_id: 1})
    assert_search_relation ["Product A"], Product.search("product").rewhere(params.permit(:store_id))
  end

  def test_where_value
    store [{name: "Product A", store_id: 1}, {name: "Product B", store_id: 2}]
    params = ActionController::Parameters.new({store_id: 1})
    assert_search "product", ["Product A"], where: {store_id: params[:store_id]}
  end

  def test_where_value_relation
    store [{name: "Product A", store_id: 1}, {name: "Product B", store_id: 2}]
    params = ActionController::Parameters.new({store_id: 1})
    assert_search_relation ["Product A"], Product.search("product").where(store_id: params[:store_id])
  end

  def test_rewhere_value_relation
    store [{name: "Product A", store_id: 1}, {name: "Product B", store_id: 2}]
    params = ActionController::Parameters.new({store_id: 1})
    assert_search_relation ["Product A"], Product.search("product").where(store_id: params[:store_id])
  end

  def test_where_hash
    params = ActionController::Parameters.new({store_id: {value: 10, boost: 2}})
    error = assert_raises(TypeError) do
      assert_search "product", [], where: {store_id: params[:store_id]}
    end
    assert_equal error.message, "can't cast ActionController::Parameters"
  end

  # TODO raise error without to_a
  def test_where_hash_relation
    params = ActionController::Parameters.new({store_id: {value: 10, boost: 2}})
    error = assert_raises(TypeError) do
      Product.search("product").where(store_id: params[:store_id]).to_a
    end
    assert_equal error.message, "can't cast ActionController::Parameters"
  end

  # TODO raise error without to_a
  def test_rewhere_hash_relation
    params = ActionController::Parameters.new({store_id: {value: 10, boost: 2}})
    error = assert_raises(TypeError) do
      Product.search("product").rewhere(store_id: params[:store_id]).to_a
    end
    assert_equal error.message, "can't cast ActionController::Parameters"
  end

  def test_aggs_where
    params = ActionController::Parameters.new({store_id: 1})
    assert_raises(ActionController::UnfilteredParameters) do
      Product.search("*", aggs: {size: {where: params}})
    end
  end

  def test_aggs_where_smart_aggs_false
    params = ActionController::Parameters.new({store_id: 1})
    assert_raises(ActionController::UnfilteredParameters) do
      Product.search("*", aggs: {size: {where: params}}, smart_aggs: false)
    end
  end
end
