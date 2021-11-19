require_relative "test_helper"

class SearchSynonymsTest < Minitest::Test
  def test_bleach
    store_names ["Clorox Bleach", "Kroger Bleach"]
    assert_search "clorox", ["Clorox Bleach", "Kroger Bleach"]
  end

  def test_burger_buns
    store_names ["Hamburger Buns"]
    assert_search "burger buns", ["Hamburger Buns"]
  end

  def test_bandaids
    store_names ["Band-Aid", "Kroger 12-Pack Bandages"]
    assert_search "bandaids", ["Band-Aid", "Kroger 12-Pack Bandages"]
  end

  def test_reverse
    store_names ["Hamburger"]
    assert_search "burger", ["Hamburger"]
  end

  def test_not_stemmed
    store_names ["Burger"]
    assert_search "hamburgers", []
    assert_search "hamburger", ["Burger"]
  end

  def test_word_start
    store_names ["Clorox Bleach", "Kroger Bleach"]
    assert_search "clorox", ["Clorox Bleach", "Kroger Bleach"], {match: :word_start}
  end

  def test_directional
    store_names ["Lightbulb", "Green Onions", "Led"]
    assert_search "led", ["Lightbulb", "Led"]
    assert_search "Lightbulb", ["Lightbulb"]
    assert_search "Halogen Lamp", ["Lightbulb"]
    assert_search "onions", ["Green Onions"]
  end

  def test_case
    store_names ["Uppercase"]
    assert_search "lowercase", ["Uppercase"]
  end

  def test_multiple_words
    store_names ["USA"]
    assert_search "United States of America", ["USA"]
    assert_search "usa", ["USA"]
    assert_search "United States", []
  end

  def test_multiple_words_expanded
    store_names ["United States of America"]
    assert_search "usa", ["United States of America"]
    assert_search "United States of America", ["United States of America"]
    assert_search "United States", ["United States of America"] # no synonyms used
  end

  def test_reload_synonyms
    if Searchkick.server_below?("7.3.0")
      error = assert_raises(Searchkick::Error) do
        Speaker.search_index.reload_synonyms
      end
      assert_equal "Requires Elasticsearch 7.3+", error.message
    else
      Speaker.search_index.reload_synonyms
    end
  end

  def test_reload_synonyms_better
    skip unless ENV["ES_PATH"] && !Searchkick.server_below?("7.3.0")

    write_synonyms("test,hello")

    with_options({search_synonyms: "synonyms.txt"}, Speaker) do
      store_names ["Hello", "Goodbye"]
      assert_search "test", ["Hello"]

      write_synonyms("test,goodbye")
      assert_search "test", ["Hello"]

      Speaker.search_index.reload_synonyms
      assert_search "test", ["Goodbye"]
    end
  ensure
    Speaker.reindex
  end

  def write_synonyms(contents)
    File.write("#{ENV.fetch("ES_PATH")}/config/synonyms.txt", contents)
  end

  def default_model
    Speaker
  end
end
