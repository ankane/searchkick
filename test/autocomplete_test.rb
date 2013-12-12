require_relative "test_helper"

class TestAutocomplete < Minitest::Test

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

end
