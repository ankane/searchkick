require_relative "test_helper"

class IndexOptionsTest < Minitest::Test
  def setup
    Song.destroy_all
  end

  def test_case_sensitive
    with_options(Song, case_sensitive: true) do
      store_names ["Test", "test"], Song
      assert_search "test", ["test"], {misspellings: false}, Song
    end
  end

  def test_no_stemming
    with_options(Song, stem: false) do
      store_names ["milk", "milks"], Song
      assert_search "milks", ["milks"], {misspellings: false}, Song
    end
  end

  def test_special_characters
    with_options(Song, special_characters: false) do
      store_names ["jalapeño"], Song
      assert_search "jalapeno", [], {misspellings: false}, Song
    end
  end
end
