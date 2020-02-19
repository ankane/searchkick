require_relative "test_helper"

class ParametersTest < Minitest::Test
  def setup
    skip unless defined?(ActiveRecord)
    require "action_controller"
    super
  end

  def test_where_hash
    params = ActionController::Parameters.new({store_id: {value: 10, boost: 2}})
    # TODO make TypeError
    error = assert_raises RuntimeError do
      assert_search "product", [], where: params
    end
    assert_includes error.message, "can't cast ActionController::Parameters"
  end
end
