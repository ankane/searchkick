require_relative "test_helper"

class AutocompleteTest < Minitest::Test
  def test_autocomplete
    store_names ["Hummus"]
    assert_search "hum", ["Hummus"], match: :text_start
  end

  def test_autocomplete_two_words
    store_names ["Organic Hummus"]
    assert_search "hum", [], match: :text_start
  end

  def test_autocomplete_fields
    store_names ["Hummus"]
    assert_search "hum", ["Hummus"], match: :text_start, fields: [:name]
  end

  def test_text_start
    store_names ["Where in the World is Carmen San Diego"]
    assert_search "where in the world is", ["Where in the World is Carmen San Diego"], fields: [{name: :text_start}]
    assert_search "in the world", [], fields: [{name: :text_start}]
  end

  def test_text_middle
    store_names ["Where in the World is Carmen San Diego"]
    assert_search "where in the world is", ["Where in the World is Carmen San Diego"], fields: [{name: :text_middle}]
    assert_search "n the wor", ["Where in the World is Carmen San Diego"], fields: [{name: :text_middle}]
    assert_search "men san diego", ["Where in the World is Carmen San Diego"], fields: [{name: :text_middle}]
    assert_search "world carmen", [], fields: [{name: :text_middle}]
  end

  def test_text_end
    store_names ["Where in the World is Carmen San Diego"]
    assert_search "men san diego", ["Where in the World is Carmen San Diego"], fields: [{name: :text_end}]
    assert_search "carmen san", [], fields: [{name: :text_end}]
  end

  def test_word_start
    store_names ["Where in the World is Carmen San Diego"]
    assert_search "car san wor", ["Where in the World is Carmen San Diego"], fields: [{name: :word_start}]
  end

  def test_word_middle
    store_names ["Where in the World is Carmen San Diego"]
    assert_search "orl", ["Where in the World is Carmen San Diego"], fields: [{name: :word_middle}]
  end

  def test_word_end
    store_names ["Where in the World is Carmen San Diego"]
    assert_search "rld men ego", ["Where in the World is Carmen San Diego"], fields: [{name: :word_end}]
  end

  def test_word_start_multiple_words
    store_names ["Dark Grey", "Dark Blue"]
    assert_search "dark grey", ["Dark Grey"], fields: [{name: :word_start}]
  end

  def test_word_start_exact
    store_names ["Back Scratcher", "Backpack"]
    assert_order "back", ["Back Scratcher", "Backpack"], fields: [{name: :word_start}]
  end

  def test_word_start_exact_martin
    store_names ["Martina", "Martin"]
    assert_order "martin", ["Martin", "Martina"], fields: [{name: :word_start}]
  end

  # TODO find a better place

  def test_exact
    store_names ["hi@example.org"]
    assert_search "hi@example.org", ["hi@example.org"], fields: [{name: :exact}]
  end
end
