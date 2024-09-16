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
    assert_search "milks", ["Milk", "Whole Milk", "Fat Free Milk"], misspellings: false
  end

  def test_stemming_tokens
    assert_equal ["milk"], Product.searchkick_index.tokens("milks", analyzer: "searchkick_search")
    assert_equal ["milk"], Product.searchkick_index.tokens("milks", analyzer: "searchkick_search2")
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

    # need to specify field
    # as transposition option isn't supported for multi_match queries
    # until Elasticsearch 6.1
    assert_search "zuccihni", [], misspellings: {transpositions: false}, fields: [:name]
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
    assert_search "redbull", ["Red Bull"], misspellings: false
  end

  def test_spaces_in_query
    store_names ["Dishwasher"]
    assert_search "dish washer", ["Dishwasher"], misspellings: false
  end

  def test_spaces_three_words
    store_names ["Dish Washer Soap", "Dish Washer"]
    assert_search "dish washer soap", ["Dish Washer Soap"]
  end

  def test_spaces_stemming
    store_names ["Almond Milk"]
    assert_search "almondmilks", ["Almond Milk"]
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

  def test_phrase_again
    store_names ["Social entrepreneurs don't have it easy raising capital"]
    assert_search "social entrepreneurs don't have it easy raising capital", ["Social entrepreneurs don't have it easy raising capital"], match: :phrase
  end

  def test_phrase_order
    store_names ["Wheat Bread", "Whole Wheat Bread"]
    assert_order "wheat bread", ["Wheat Bread", "Whole Wheat Bread"], match: :phrase, fields: [:name]
  end

  def test_dynamic_fields
    setup_speaker
    store_names ["Red Bull"], Speaker
    assert_search "redbull", ["Red Bull"], {fields: [:name]}, Speaker
  end

  def test_unsearchable
    skip
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
    store_names ["Banana"]
    assert_search "🍌", ["Banana"], emoji: true
  end

  def test_emoji_multiple
    store_names ["Ice Cream Cake"]
    assert_search "🍨🍰", ["Ice Cream Cake"], emoji: true
    assert_search "🍨🍰", ["Ice Cream Cake"], emoji: true, misspellings: false
  end

  # operator

  def test_operator
    store_names ["fresh", "honey"]
    assert_search "fresh honey", ["fresh", "honey"], {operator: "or"}
    assert_search "fresh honey", [], {operator: "and"}
    assert_search "fresh honey", ["fresh", "honey"], {operator: :or}
    assert_search "fresh honey", ["fresh", "honey"], {operator: :or, body_options: {track_total_hits: true}}
    assert_search "fresh honey", [], {operator: :or, fields: [:name], match: :phrase, body_options: {track_total_hits: true}}
  end

  def test_operator_scoring
    store_names ["Big Red Circle", "Big Green Circle", "Small Orange Circle"]
    assert_order "big red circle", ["Big Red Circle", "Big Green Circle", "Small Orange Circle"], operator: "or"
  end

  # fields

  def test_fields_operator
    store [
      {name: "red", color: "red"},
      {name: "blue", color: "blue"},
      {name: "cyan", color: "blue green"},
      {name: "magenta", color: "red blue"},
      {name: "green", color: "green"}
    ]
    assert_search "red blue", ["red", "blue", "cyan", "magenta"], operator: "or", fields: ["color"]
  end

  def test_fields
    store [
      {name: "red", color: "light blue"},
      {name: "blue", color: "red fish"}
    ]
    assert_search "blue", ["red"], fields: ["color"]
  end

  def test_non_existent_field
    store_names ["Milk"]
    assert_search "milk", [], fields: ["not_here"]
  end

  def test_fields_both_match
    # have same score due to dismax
    store [
      {name: "Blue A", color: "red"},
      {name: "Blue B", color: "light blue"}
    ]
    assert_first "blue", "Blue B", fields: [:name, :color]
  end
end
