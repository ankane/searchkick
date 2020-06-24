require_relative "test_helper"

class IndexOptionsTest < Minitest::Test
  def setup
    Song.destroy_all
  end

  def test_case_sensitive
    with_options({case_sensitive: true}) do
      store_names ["Test", "test"]
      assert_search "test", ["test"], {misspellings: false}
    end
  end

  def test_no_stemming
    with_options({stem: false}) do
      store_names ["milk", "milks"]
      assert_search "milks", ["milks"], {misspellings: false}
    end
  end

  def test_no_stem_exclusion
    with_options({}) do
      store_names ["animals", "anime"]
      assert_search "animals", ["animals", "anime"], {misspellings: false}
      assert_search "anime", ["animals", "anime"], {misspellings: false}
      assert_equal ["anim"], Song.search_index.tokens("anime", analyzer: "searchkick_index")
      assert_equal ["anim"], Song.search_index.tokens("anime", analyzer: "searchkick_search2")
    end
  end

  def test_stem_exclusion
    with_options({stem_exclusion: ["anime"]}) do
      store_names ["animals", "anime"]
      assert_search "animals", ["animals"], {misspellings: false}
      assert_search "anime", ["anime"], {misspellings: false}
      assert_equal ["anime"], Song.search_index.tokens("anime", analyzer: "searchkick_index")
      assert_equal ["anime"], Song.search_index.tokens("anime", analyzer: "searchkick_search2")
    end
  end

  def test_special_characters
    with_options({special_characters: false}) do
      store_names ["jalapeño"]
      assert_search "jalapeno", [], {misspellings: false}
    end
  end

  def default_model
    Song
  end
end
