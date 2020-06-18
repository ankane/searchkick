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

  def test_exclude
    store_names ["Dark Grey", "Dark Blue"]
    assert_search "da", ["Dark Grey"], exclude: "blue"
  end

  def test_ranking
    expected = ["one two three", "one two other three", "one other two other three"]
    store_names expected
    assert_order "one two three", expected
  end

  def default_model
    Item
  end
end
