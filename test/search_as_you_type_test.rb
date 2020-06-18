require_relative "test_helper"

class SearchAsYouTypeTest < Minitest::Test
  def setup
    Item.destroy_all
  end

  def test_works
    store_names ["Hummus"]
    assert_search "hum", ["Hummus"]
  end

  def test_multiple_words
    store_names ["Dark Grey", "Dark Blue"]
    assert_search "dark gr", ["Dark Grey"]
  end

  def test_operator
    store_names ["Dark Grey", "Dark Blue"]
    assert_search "dark gr", ["Dark Grey", "Dark Blue"], operator: "or"
  end

  def default_model
    Item
  end
end
