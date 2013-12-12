require_relative "test_helper"

class TestHighlight < Minitest::Test

  def test_basic
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <em>Cinema</em> Club", Product.search("cinema", fields: [:name], highlight: true).with_details.first[1][:highlight][:name]
  end

  def test_tag
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <strong>Cinema</strong> Club", Product.search("cinema", fields: [:name], highlight: {tag: "<strong>"}).with_details.first[1][:highlight][:name]
  end

  def test_multiple_fields
    store [{name: "Two Door Cinema Club", color: "Cinema Orange"}]
    highlight = Product.search("cinema", fields: [:name, :color], highlight: true).with_details.first[1][:highlight]
    assert_equal "Two Door <em>Cinema</em> Club", highlight[:name]
    assert_equal "<em>Cinema</em> Orange", highlight[:color]
  end

end
