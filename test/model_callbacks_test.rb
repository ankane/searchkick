require_relative "test_helper"

class ModelCallbacksTest < Minitest::Test

  def test_callbacks
    topic = Topic.new(name: "Topic A")
    topic.save
    assert_equal true, topic.before_called
    assert_equal true, topic.after_called
  end

end
