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
