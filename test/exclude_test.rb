require_relative "test_helper"

class ExcludeTest < Minitest::Test
  def test_butter
    store_names ["Butter Tub", "Peanut Butter Tub"]
    assert_search "butter", ["Butter Tub"], exclude: ["peanut butter"]
  end

  def test_butter_word_start
    store_names ["Butter Tub", "Peanut Butter Tub"]
    assert_search "butter", ["Butter Tub"], exclude: ["peanut butter"], match: :word_start
  end

  def test_butter_exact
    store_names ["Butter Tub", "Peanut Butter Tub"]
    assert_search "butter", [], exclude: ["peanut butter"], fields: [{name: :exact}]
  end

  def test_same_exact
    store_names ["Butter Tub", "Peanut Butter Tub"]
    assert_search "Butter Tub", ["Butter Tub"], exclude: ["Peanut Butter Tub"], fields: [{name: :exact}]
  end

  def test_egg_word_start
    store_names ["eggs", "eggplant"]
    assert_search "egg", ["eggs"], exclude: ["eggplant"], match: :word_start
  end

  def test_string
    store_names ["Butter Tub", "Peanut Butter Tub"]
    assert_search "butter", ["Butter Tub"], exclude: "peanut butter"
  end

  def test_match_all
    store_names ["Butter"]
    assert_search "*", [], exclude: "butter"
  end

  def test_match_all_fields
    store_names ["Butter"]
    assert_search "*", [], fields: [:name], exclude: "butter"
    assert_search "*", ["Butter"], fields: [:color], exclude: "butter"
  end
end
