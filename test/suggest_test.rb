require_relative "test_helper"

class TestSuggest < Minitest::Unit::TestCase

  def test_basic
    store_names ["Great White Shark", "Hammerhead Shark", "Tiger Shark"]
    assert_suggest "How Big is a Tigre Shar", "how big is a tiger shark"
  end

  def test_perfect
    store_names ["Tiger Shark", "Great White Shark"]
    assert_suggest "Tiger Shark", nil # no correction
  end

  def test_phrase
    store_names ["Big Tiger Shark", "Tiger Sharp Teeth", "Tiger Sharp Mind"]
    assert_suggest "How to catch a big tiger shar", "how to catch a big tiger shark"
  end

  def test_without_option
    assert_raises(RuntimeError){ Product.search("hi").suggestions }
  end

  def test_multiple_fields
    store [
      {name: "Shark", color: "Sharp"}
    ]
    assert_suggest_all "shar", ["shark", "sharp"]
  end

  def test_multiple_fields_highest_score_first
    store [
      {name: "Tiger Shark", color: "Sharp"}
    ]
    assert_suggest "tiger shar", "tiger shark"
  end

  def test_multiple_fields_same_value
    store [
      {name: "Shark", color: "Shark"}
    ]
    assert_suggest_all "shar", ["shark"]
  end

  def test_fields_option
    store [
      {name: "Shark", color: "Sharp"}
    ]
    assert_suggest_all "shar", ["shark"], fields: [:name]
  end

  protected

  def assert_suggest(term, expected)
    assert_equal expected, Product.search(term, suggest: true).suggestions.first
  end

  # any order
  def assert_suggest_all(term, expected, options = {})
    assert_equal expected.sort, Product.search(term, options.merge(suggest: true)).suggestions.sort
  end

end
