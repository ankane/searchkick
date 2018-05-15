require_relative "test_helper"

class FieldMisspellingTest < Minitest::Test
  def test_misspellings_field_correct_spelling_still_works
    store [{name: "Sriracha", color: "blue"}]
    assert_misspellings "Sriracha", ["Sriracha"], {fields: {name: false, color: false}}
    assert_misspellings "blue", ["Sriracha"], {fields: {name: false, color: false }}
  end

  def test_misspellings_field_enabled
    store [{name: "Sriracha", color: "blue"}]
    assert_misspellings "siracha", ["Sriracha"], {fields: {name: true}}
    assert_misspellings "clue", ["Sriracha"], {fields: {color: true}}
  end

  def test_misspellings_field_disabled
    store [{name: "Sriracha", color: "blue"}]
    assert_misspellings "siracha", [], {fields: {name: false}}
    assert_misspellings "clue", [], {fields: {color: false}}
  end

  def test_misspellings_field__color
    store [{name: "Sriracha", color: "blue"}]
    assert_misspellings "bluu", ["Sriracha"], {fields: {name: false, color: true}}
  end

  def test_misspellings_field_multiple
    store [
      {name: "Greek Yogurt", color: "white"},
      {name: "Green Onions", color: "yellow"}
    ]
    assert_misspellings "greed", ["Greek Yogurt", "Green Onions"], {fields: {name: true, color: false}}
    assert_misspellings "greed", [], {fields: {name: false, color: true}}
  end

  def test_misspellings_field_unspecified_uses_edit_distance_one
    store [{name: "Bingo", color: "blue"}]
    assert_misspellings "bin", [], {fields: {color: {edit_distance: 2}}}
    assert_misspellings "bingooo", [], {fields: {color: {edit_distance: 2}}}
    assert_misspellings "mango", [], {fields: {color: {edit_distance: 2}}}
    assert_misspellings "bing", ["Bingo"], {fields: {color: {edit_distance: 2}}}
  end

  def test_misspellings_field_uses_specified_edit_distance
    store [{name: "Bingo", color: "yellow"}]
    assert_misspellings "yell", ["Bingo"], {fields: {color: {edit_distance: 2}}}
    assert_misspellings "yellowww", ["Bingo"], {fields: {color: {edit_distance: 2}}}
    assert_misspellings "yilliw", ["Bingo"], {fields: {color: {edit_distance: 2}}}
  end

  def test_misspellings_field_zucchini_transposition
    store [{name: "zucchini", color: "green"}]
    assert_misspellings "zuccihni", [], {fields: {name: {transpositions: false}}}
    assert_misspellings "grene", ["zucchini"], {fields: {name: {transpositions: false}}}
  end

  def test_misspellings_field_transposition_combination
    store [{name: "zucchini", color: "green"}]
    misspellings = {
        transpositions: false,
        fields: {color: {transpositions: true}}
    }
    assert_misspellings "zuccihni", [], misspellings
    assert_misspellings "greene", ["zucchini"], misspellings
  end

  def test_misspellings_field_word_start
    store_names ["Sriracha"]
    assert_misspellings "siracha", ["Sriracha"], {fields: {name: true}}
  end

  def test_misspellings_field_and_transpositions
    store [{name: "Sriracha", color: "green"}]
    options = {
      fields: [{name: :word_start}],
      misspellings: {
        transpositions: false,
        fields: {name: true}
      }
    }
    assert_search "grene", [], options
    assert_search "srircaha", ["Sriracha"], options
  end

  def test_misspellings_field_and_edit_distance
    store [{name: "Sriracha", color: "green"}]
    options = {edit_distance: 2, fields: {name: true}}
    assert_misspellings "greennn", ["Sriracha"], options
    assert_misspellings "srirachaaa", [], options
    assert_misspellings "siracha", ["Sriracha"], options
  end

  def test_misspellings_field_requires_explicit_search_fields
    store_names ["Sriracha"]
    assert_raises(ArgumentError) do
      assert_search "siracha", ["Sriracha"], {misspellings: {fields: {name: false}}}
    end
  end
end
