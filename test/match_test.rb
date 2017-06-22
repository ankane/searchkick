require_relative "test_helper"

class MatchTest < Minitest::Test
  # exact

  def test_match
    store_names ["Whole Milk", "Fat Free Milk", "Milk"]
    assert_search "milk", ["Milk", "Whole Milk", "Fat Free Milk"]
  end

  def test_case
    store_names ["Whole Milk", "Fat Free Milk", "Milk"]
    assert_search "MILK", ["Milk", "Whole Milk", "Fat Free Milk"]
  end

  def test_cheese_space_in_index
    store_names ["Pepper Jack Cheese Skewers"]
    assert_search "pepperjack cheese skewers", ["Pepper Jack Cheese Skewers"]
  end

  # def test_cheese_space_in_query
  #   store_names ["Pepperjack Cheese Skewers"]
  #   assert_search "pepper jack cheese skewers", ["Pepperjack Cheese Skewers"]
  # end

  def test_middle_token
    store_names ["Dish Washer Amazing Organic Soap"]
    assert_search "dish soap", ["Dish Washer Amazing Organic Soap"]
  end

  def test_middle_token_wine
    store_names ["Beringer Wine Founders Estate Chardonnay"]
    assert_search "beringer chardonnay", ["Beringer Wine Founders Estate Chardonnay"]
  end

  def test_percent
    # Note: "2% Milk" doesn't get matched in ES below 5.1.1
    # This could be a bug since it has an edit distance of 1
    store_names ["1% Milk", "Whole Milk"]
    assert_search "1%", ["1% Milk"]
  end

  # ascii

  def test_jalapenos
    store_names ["Jalapeño"]
    assert_search "jalapeno", ["Jalapeño"]
  end

  def test_swedish
    store_names ["ÅÄÖ"]
    assert_search "aao", ["ÅÄÖ"]
  end

  # stemming

  def test_stemming
    store_names ["Whole Milk", "Fat Free Milk", "Milk"]
    assert_search "milks", ["Milk", "Whole Milk", "Fat Free Milk"]
  end

  # fuzzy

  def test_misspelling_sriracha
    store_names ["Sriracha"]
    assert_search "siracha", ["Sriracha"]
  end

  def test_misspelling_multiple
    store_names ["Greek Yogurt", "Green Onions"]
    assert_search "greed", ["Greek Yogurt", "Green Onions"]
  end

  def test_short_word
    store_names ["Finn"]
    assert_search "fin", ["Finn"]
  end

  def test_edit_distance_two
    store_names ["Bingo"]
    assert_search "bin", []
    assert_search "bingooo", []
    assert_search "mango", []
  end

  def test_edit_distance_one
    store_names ["Bingo"]
    assert_search "bing", ["Bingo"]
    assert_search "bingoo", ["Bingo"]
    assert_search "ringo", ["Bingo"]
  end

  def test_edit_distance_long_word
    store_names ["thisisareallylongword"]
    assert_search "thisisareallylongwor", ["thisisareallylongword"] # missing letter
    assert_search "thisisareelylongword", [] # edit distance = 2
  end

  def test_misspelling_tabasco
    store_names ["Tabasco"]
    assert_search "tobasco", ["Tabasco"]
  end

  def test_misspelling_zucchini
    store_names ["Zucchini"]
    assert_search "zuchini", ["Zucchini"]
  end

  def test_misspelling_ziploc
    store_names ["Ziploc"]
    assert_search "zip lock", ["Ziploc"]
  end

  def test_misspelling_zucchini_transposition
    store_names ["zucchini"]
    assert_search "zuccihni", ["zucchini"]
    assert_search "zuccihni", [], misspellings: {transpositions: false}
  end

  def test_misspelling_lasagna
    store_names ["lasagna"]
    assert_search "lasanga", ["lasagna"], misspellings: {transpositions: true}
    assert_search "lasgana", ["lasagna"], misspellings: {transpositions: true}
    assert_search "lasaang", [], misspellings: {transpositions: true} # triple transposition, shouldn't work
    assert_search "lsagana", [], misspellings: {transpositions: true} # triple transposition, shouldn't work
  end

  def test_misspelling_lasagna_pasta
    store_names ["lasagna pasta"]
    assert_search "lasanga", ["lasagna pasta"], misspellings: {transpositions: true}
    assert_search "lasanga pasta", ["lasagna pasta"], misspellings: {transpositions: true}
    assert_search "lasanga pasat", ["lasagna pasta"], misspellings: {transpositions: true} # both words misspelled with a transposition should still work
  end

  def test_misspellings_word_start
    store_names ["Sriracha"]
    assert_search "siracha", ["Sriracha"], fields: [{name: :word_start}]
  end

  # spaces

  def test_spaces_in_field
    store_names ["Red Bull"]
    assert_search "redbull", ["Red Bull"]
  end

  def test_spaces_in_query
    store_names ["Dishwasher"]
    assert_search "dish washer", ["Dishwasher"]
  end

  def test_spaces_three_words
    store_names ["Dish Washer Soap", "Dish Washer"]
    assert_search "dish washer soap", ["Dish Washer Soap"]
  end

  def test_spaces_stemming
    store_names ["Almond Milk"]
    assert_search "almondmilks", ["Almond Milk"]
  end

  # butter

  def test_exclude_butter
    store_names ["Butter Tub", "Peanut Butter Tub"]
    assert_search "butter", ["Butter Tub"], exclude: ["peanut butter"]
  end

  def test_exclude_butter_word_start
    store_names ["Butter Tub", "Peanut Butter Tub"]
    assert_search "butter", ["Butter Tub"], exclude: ["peanut butter"], match: :word_start
  end

  def test_exclude_butter_exact
    store_names ["Butter Tub", "Peanut Butter Tub"]
    assert_search "butter", [], exclude: ["peanut butter"], match: :exact
  end

  def test_exclude_same_exact
    store_names ["Butter Tub", "Peanut Butter Tub"]
    assert_search "Butter Tub", [], exclude: ["Butter Tub"], match: :exact
  end

  def test_exclude_egg_word_start
    store_names ["eggs", "eggplant"]
    assert_search "egg", ["eggs"], exclude: ["eggplant"], match: :word_start
  end

  def test_exclude_string
    store_names ["Butter Tub", "Peanut Butter Tub"]
    assert_search "butter", ["Butter Tub"], exclude: "peanut butter"
  end

  # other

  def test_all
    store_names ["Product A", "Product B"]
    assert_search "*", ["Product A", "Product B"]
  end

  def test_no_arguments
    store_names []
    assert_equal [], Product.search.to_a
  end

  def test_no_term
    store_names ["Product A"]
    assert_equal ["Product A"], Product.search(where: {name: "Product A"}).map(&:name)
  end

  def test_to_be_or_not_to_be
    store_names ["to be or not to be"]
    assert_search "to be", ["to be or not to be"]
  end

  def test_apostrophe
    store_names ["Ben and Jerry's"]
    assert_search "ben and jerrys", ["Ben and Jerry's"]
  end

  def test_apostrophe_search
    store_names ["Ben and Jerrys"]
    assert_search "ben and jerry's", ["Ben and Jerrys"]
  end

  def test_ampersand_index
    store_names ["Ben & Jerry's"]
    assert_search "ben and jerrys", ["Ben & Jerry's"]
  end

  def test_ampersand_search
    store_names ["Ben and Jerry's"]
    assert_search "ben & jerrys", ["Ben and Jerry's"]
  end

  def test_phrase
    store_names ["Fresh Honey", "Honey Fresh"]
    assert_search "fresh honey", ["Fresh Honey"], match: :phrase
  end

  def test_phrase_order
    store_names ["Wheat Bread", "Whole Wheat Bread"]
    assert_order "wheat bread", ["Wheat Bread", "Whole Wheat Bread"], match: :phrase
  end

  def test_dynamic_fields
    store_names ["Red Bull"], Speaker
    assert_search "redbull", ["Red Bull"], {fields: [:name]}, Speaker
  end

  def test_unsearchable
    store [
      {name: "Unsearchable", description: "Almond"}
    ]
    assert_search "almond", []
  end

  def test_unsearchable_where
    store [
      {name: "Unsearchable", description: "Almond"}
    ]
    assert_search "*", ["Unsearchable"], where: {description: "Almond"}
  end

  def test_emoji
    skip unless defined?(EmojiParser)
    store_names ["Banana"]
    assert_search "🍌", ["Banana"], emoji: true
  end

  def test_emoji_multiple
    skip unless defined?(EmojiParser)
    store_names ["Ice Cream Cake"]
    assert_search "🍨🍰", ["Ice Cream Cake"], emoji: true
  end
end
