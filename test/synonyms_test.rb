require_relative "test_helper"

class SynonymsTest < Minitest::Test
  def test_bleach
    store_names ["Clorox Bleach", "Kroger Bleach"]
    assert_search "clorox", ["Clorox Bleach", "Kroger Bleach"]
  end

  def test_saran_wrap
    store_names ["Saran Wrap", "Kroger Plastic Wrap"]
    assert_search "saran wrap", ["Saran Wrap", "Kroger Plastic Wrap"]
  end

  def test_burger_buns
    store_names ["Hamburger Buns"]
    assert_search "burger buns", ["Hamburger Buns"]
  end

  def test_bandaids
    store_names ["Band-Aid", "Kroger 12-Pack Bandages"]
    assert_search "bandaids", ["Band-Aid", "Kroger 12-Pack Bandages"]
  end

  def test_qtips
    store_names ["Q Tips", "Kroger Cotton Swabs"]
    assert_search "q tips", ["Q Tips", "Kroger Cotton Swabs"]
  end

  def test_reverse
    store_names ["Scallions"]
    assert_search "green onions", ["Scallions"]
  end

  def test_exact
    store_names ["Green Onions", "Yellow Onions"]
    assert_search "scallion", ["Green Onions"]
  end

  def test_stemmed
    store_names ["Green Onions", "Yellow Onions"]
    assert_search "scallions", ["Green Onions"]
  end

  def test_word_start
    store_names ["Clorox Bleach", "Kroger Bleach"]
    assert_search "clorox", ["Clorox Bleach", "Kroger Bleach"], fields: [{name: :word_start}]
  end

  def test_wordnet
    skip unless ENV["TEST_WORDNET"]
    store_names ["Creature", "Beast", "Dragon"], Animal
    assert_search "animal", ["Creature", "Beast"], {}, Animal
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
end
