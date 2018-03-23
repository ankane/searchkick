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
      assert_language_search "中华人民共和国", ["中华人民共和国国歌"]
      assert_language_search "国歌", ["中华人民共和国国歌"]
      assert_language_search "人", []
    end
  end

  # experimental
  def test_smartcn
    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/6.2/analysis-smartcn.html
    with_options(Song, language: "smartcn") do
      store_names ["中华人民共和国国歌"], Song
      assert_language_search "中华人民共和国", ["中华人民共和国国歌"]
      # assert_language_search "国歌", ["中华人民共和国国歌"]
      assert_language_search "人", []
    end
  end

  def test_japanese
    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/6.2/analysis-kuromoji.html
    with_options(Song, language: "japanese") do
      store_names ["JR新宿駅の近くにビールを飲みに行こうか"], Song
      assert_language_search "飲む", ["JR新宿駅の近くにビールを飲みに行こうか"]
      assert_language_search "jr", ["JR新宿駅の近くにビールを飲みに行こうか"]
      assert_language_search "新", []
    end
  end

  def test_korean
    # requires https://github.com/open-korean-text/elasticsearch-analysis-openkoreantext
    with_options(Song, language: "korean") do
      store_names ["한국어를 처리하는 예시입니닼ㅋㅋ"], Song
      assert_language_search "처리", ["한국어를 처리하는 예시입니닼ㅋㅋ"]
      assert_language_search "한국어", ["한국어를 처리하는 예시입니닼ㅋㅋ"]
      assert_language_search "를", []
    end
  end

  def test_polish
    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/6.2/analysis-stempel.html
    with_options(Song, language: "polish") do
      store_names ["polski"], Song
      assert_language_search "polskimi", ["polski"]
    end
  end

  def test_ukrainian
    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/6.2/analysis-ukrainian.html
    with_options(Song, language: "ukrainian") do
      store_names ["ресторани"], Song
      assert_language_search "ресторан", ["ресторани"]
    end
  end

  def test_vietnamese
    # requires https://github.com/duydo/elasticsearch-analysis-vietnamese
    with_options(Song, language: "vietnamese") do
      store_names ["công nghệ thông tin Việt Nam"], Song
      assert_language_search "công nghệ thông tin", ["công nghệ thông tin Việt Nam"]
      assert_language_search "công", []
    end
  end

  def assert_language_search(term, expected)
    assert_search term, expected, {misspellings: false}, Song
  end
end
