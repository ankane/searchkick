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

  # search time synonyms do not match partial words
  def test_search_synonyms
    store_names ["Hello", "Goodbye"]
    assert_search "greeting", ["Hello"]
  end

  def test_misspellings
    store_names ["Tabasco Sauce"]
    assert_search "tobasco s", [], misspellings: false
    assert_search "tobasco s", ["Tabasco Sauce"]
  end

  # fuzziness is not applied to last term
  # https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-multi-match-query.html#type-bool-prefix
  #
  # not sure there's much we can do here right now
  # ideally we could search both term and prefix for final term
  # https://github.com/elastic/elasticsearch/issues/56229
  def test_mispellings_last_term
    store_names ["Tabasco"]
    assert_search "tobasco", []
  end

  def default_model
    Item
  end
end
