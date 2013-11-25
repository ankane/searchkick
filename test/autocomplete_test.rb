require_relative "test_helper"

class TestAutocomplete < Minitest::Unit::TestCase

  def test_autocomplete
    store_names ["Hummus"]
    assert_search "hum", ["Hummus"], autocomplete: true
  end

  def test_autocomplete_two_words
    store_names ["Organic Hummus"]
    assert_search "hum", [], autocomplete: true
  end

  def test_autocomplete_fields
    store_names ["Hummus"]
    assert_search "hum", ["Hummus"], autocomplete: true, fields: [:name]
  end

  def test_text_start
    store_names ["Where in the World is Carmen San Diego?"]
    assert_search "whe", ["Where in the World is Carmen San Diego?"], fields: [{name: :text_start}]
  end

  def test_text_middle
    store_names ["Where in the World is Carmen San Diego?"]
    assert_search "n the wor", ["Where in the World is Carmen San Diego?"], fields: [{name: :text_middle}]
  end

  def test_text_end
    store_names ["Where in the World is Carmen San Diego?"]
    assert_search "ego", ["Where in the World is Carmen San Diego?"], fields: [{name: :text_end}]
  end

  def test_word_start
    store_names ["Where in the World is Carmen San Diego?"]
    assert_search "car", ["Where in the World is Carmen San Diego?"], fields: [{name: :word_start}]
  end

  def test_word_middle
    store_names ["Where in the World is Carmen San Diego?"]
    assert_search "orl", ["Where in the World is Carmen San Diego?"], fields: [{name: :word_middle}]
  end

  def test_word_end
    store_names ["Where in the World is Carmen San Diego?"]
    assert_search "men", ["Where in the World is Carmen San Diego?"], fields: [{name: :word_end}]
  end

end
