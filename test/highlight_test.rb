require_relative "test_helper"

class TestHighlight < Minitest::Unit::TestCase

  def test_basic
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <em>Cinema</em> Club", Product.search("cinema", fields: [:name], highlight: true).each_with_hit.first[1]["highlight"]["name.analyzed"].first
  end

  def test_tag
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <strong>Cinema</strong> Club", Product.search("cinema", fields: [:name], highlight: {tag: "<strong>"}).each_with_hit.first[1]["highlight"]["name.analyzed"].first
  end

  def test_multiple_fields
    store [{name: "Two Door Cinema Club", color: "Cinema Orange"}]
    highlight = Product.search("cinema", fields: [:name, :color], highlight: true).each_with_hit.first[1]["highlight"]
    assert_equal "Two Door <em>Cinema</em> Club", highlight["name.analyzed"].first
    assert_equal "<em>Cinema</em> Orange", highlight["color.analyzed"].first
  end

end
