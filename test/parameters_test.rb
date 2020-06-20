require_relative "test_helper"

class ParametersTest < Minitest::Test
  def setup
    require "action_controller"
    super
  end

  def test_where_unpermitted
    # TODO raise error in Searchkick 6
    store [{name: "Product A", store_id: 1}, {name: "Product B", store_id: 2}]
    params = ActionController::Parameters.new({store_id: 1})
    assert_search "product", ["Product A"], where: params
  end

  def test_where_permitted
    store [{name: "Product A", store_id: 1}, {name: "Product B", store_id: 2}]
    params = ActionController::Parameters.new({store_id: 1})
    assert_search "product", ["Product A"], where: params.permit!
  end

  def test_where_hash
    params = ActionController::Parameters.new({store_id: {value: 10, boost: 2}})
    # TODO make TypeError
    error = assert_raises Searchkick::InvalidQueryError do
      assert_search "product", [], where: {store_id: params[:store_id]}
    end
    assert_equal error.message, "can't cast ActionController::Parameters"
  end
end
