require_relative "test_helper"

class CaseSensitiveTest < Minitest::Test
  def setup
    Song.destroy_all
  end

  def test_case_sensitive
    with_options(Song, case_sensitive: true) do
      store_names ["Test", "test"], Song
      assert_search "test", ["test"], {misspellings: false}, Song
    end
  end
end
