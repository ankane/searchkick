require_relative "test_helper"

class LanguageTest < Minitest::Test
  def setup
    Song.destroy_all
  end

  def test_chinese
    skip unless ENV["CHINESE"]
    store_names ["中华人民共和国国歌"], Song
    assert_search "中华人民共和国", ["中华人民共和国国歌"], {}, Song
    assert_search "国歌", ["中华人民共和国国歌"], {}, Song
    assert_search "人", [], {}, Song
  end
end
