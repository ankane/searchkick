require_relative "test_helper"

class LanguageTest < Minitest::Test
  def setup
    skip "Requires plugin" unless ci? || ENV["TEST_LANGUAGE"]

    Song.destroy_all
  end

  def test_chinese
    skip if ci?

    # requires https://github.com/medcl/elasticsearch-analysis-ik
    with_options({language: "chinese"}) do
      store_names ["中华人民共和国国歌"]
      assert_language_search "中华人民共和国", ["中华人民共和国国歌"]
      assert_language_search "国歌", ["中华人民共和国国歌"]
      assert_language_search "人", []
    end
  end

  def test_chinese2
    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/7.4/analysis-smartcn.html
    with_options({language: "chinese2"}) do
      store_names ["中华人民共和国国歌"]
      assert_language_search "中华人民共和国", ["中华人民共和国国歌"]
      # assert_language_search "国歌", ["中华人民共和国国歌"]
      assert_language_search "人", []
    end
  end

  def test_japanese
    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/7.4/analysis-kuromoji.html
    with_options({language: "japanese"}) do
      store_names ["JR新宿駅の近くにビールを飲みに行こうか"]
      assert_language_search "飲む", ["JR新宿駅の近くにビールを飲みに行こうか"]
      assert_language_search "jr", ["JR新宿駅の近くにビールを飲みに行こうか"]
      assert_language_search "新", []
    end
  end

  def test_japanese_search_synonyms
    error = assert_raises(Searchkick::Error) do
      with_options({language: "japanese", search_synonyms: [["飲む", "喰らう"]]}) do
      end
    end
    assert_equal "Search synonyms are not supported yet for language", error.message
  end

  def test_japanese2
    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/7.4/analysis-kuromoji.html
    with_options({language: "japanese2"}) do
      store_names ["JR新宿駅の近くにビールを飲みに行こうか"]
      assert_language_search "飲む", ["JR新宿駅の近くにビールを飲みに行こうか"]
      assert_language_search "jr", ["JR新宿駅の近くにビールを飲みに行こうか"]
      assert_language_search "新", []
    end
  end

  def test_japanese2_search_synonyms
    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/7.4/analysis-kuromoji.html
    with_options({language: "japanese2", search_synonyms: [["飲む", "喰らう"]]}) do
      store_names ["JR新宿駅の近くにビールを飲みに行こうか"]
      assert_language_search "喰らう", ["JR新宿駅の近くにビールを飲みに行こうか"]
      assert_language_search "新", []
    end
  end

  def test_korean
    skip if ci?

    # requires https://github.com/open-korean-text/elasticsearch-analysis-openkoreantext
    with_options({language: "korean"}) do
      store_names ["한국어를 처리하는 예시입니닼ㅋㅋ"]
      assert_language_search "처리", ["한국어를 처리하는 예시입니닼ㅋㅋ"]
      assert_language_search "한국어", ["한국어를 처리하는 예시입니닼ㅋㅋ"]
      assert_language_search "를", []
    end
  end

  def test_korean2
    skip if Searchkick.server_below?("6.4.0") || ci?

    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/7.4/analysis-nori.html
    with_options({language: "korean2"}) do
      store_names ["한국어를 처리하는 예시입니닼ㅋㅋ"]
      assert_language_search "처리", ["한국어를 처리하는 예시입니닼ㅋㅋ"]
      assert_language_search "한국어", ["한국어를 처리하는 예시입니닼ㅋㅋ"]
      assert_language_search "를", []
    end
  end

  def test_polish
    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/7.4/analysis-stempel.html
    with_options({language: "polish"}) do
      store_names ["polski"]
      assert_language_search "polskimi", ["polski"]
    end
  end

  def test_ukrainian
    # requires https://www.elastic.co/guide/en/elasticsearch/plugins/7.4/analysis-ukrainian.html
    with_options({language: "ukrainian"}) do
      store_names ["ресторани"]
      assert_language_search "ресторан", ["ресторани"]
    end
  end

  def test_vietnamese
    skip if ci?

    # requires https://github.com/duydo/elasticsearch-analysis-vietnamese
    with_options({language: "vietnamese"}) do
      store_names ["công nghệ thông tin Việt Nam"]
      assert_language_search "công nghệ thông tin", ["công nghệ thông tin Việt Nam"]
      assert_language_search "công", []
    end
  end

  def test_stemmer_hunspell
    skip if ci?

    with_options({stemmer: {type: "hunspell", locale: "en_US"}}) do
      store_names ["the foxes jumping quickly"]
      assert_language_search "fox", ["the foxes jumping quickly"]
    end
  end

  def test_stemmer_unknown_type
    error = assert_raises(ArgumentError) do
      with_options({stemmer: {type: "bad"}}) do
      end
    end
    assert_equal "Unknown stemmer: bad", error.message
  end

  def test_stemmer_language
    skip if ci?

    error = assert_raises(ArgumentError) do
      with_options({stemmer: {type: "hunspell", locale: "en_US"}, language: "english"}) do
      end
    end
    assert_equal "Can't pass both language and stemmer", error.message
  end

  def assert_language_search(term, expected)
    assert_search term, expected, {misspellings: false}
  end

  def default_model
    Song
  end
end
