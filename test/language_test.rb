require_relative "test_helper"

class LanguageTest < Minitest::Test
  def setup
    skip unless ENV["LANGUAGE"]

    Song.destroy_all
  end

  def test_chinese
    # requires https://github.com/medcl/elasticsearch-analysis-ik
    with_options(Song, language: "chinese") do
      store_names ["中华人民共和国国歌"], Song
      assert_search "中华人民共和国", ["中华人民共和国国歌"], {}, Song
      assert_search "国歌", ["中华人民共和国国歌"], {}, Song
      assert_search "人", [], {}, Song
    end
  end

  def test_ukrainian
    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/6.2/analysis-ukrainian.html
    with_options(Song, language: "ukrainian") do
      store_names ["ресторани"], Song
      assert_search "ресторан", ["ресторани"], {misspellings: false}, Song
    end
  end
end
