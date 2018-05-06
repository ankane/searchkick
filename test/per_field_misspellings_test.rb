require_relative "test_helper"

class FieldMisspellingTest < Minitest::Test
  def test_correct_spelling_still_works
    store [{name: "Sriracha", color: "blue"}]
    params = {
      fields: [:name, :color],
      misspellings: { fields: { name: false, color: false } }
    }
    assert_search "Sriracha", ["Sriracha"], params
    assert_search "blue", ["Sriracha"], params
  end

  def test_misspelling_enabled
    store [{name: "Sriracha", color: "blue"}]
    assert_search "siracha", ["Sriracha"],
      fields: [:name, :color],
      misspellings: { fields: { name: true } }
    assert_search "clue", ["Sriracha"],
      fields: [:name, :color],
      misspellings: { fields: { color: true } }
  end

  def test_misspelling_disabled
    store [{name: "Sriracha", color: "blue"}]
    assert_search "siracha", [],
      fields: [:name, :color],
      misspellings: { fields: { name: false } }
    assert_search "clue", [],
      fields: [:name, :color],
      misspellings: { fields: { color: false } }
  end

  def test_misspelling_color
    store [{name: "Sriracha", color: "blue"}]
    assert_search "bluu", ["Sriracha"],
      fields: [:name, :color],
      misspellings: { fields: { name: false, color: true } }
  end

  def test_misspelling_multiple
    store [
      {name: "Greek Yogurt", color: "white"},
      {name: "Green Onions", color: "yellow"}
    ]
    assert_search "greed", ["Greek Yogurt", "Green Onions"],
      fields: [:name, :color],
      misspellings: { fields: { name: true, color: false } }
    assert_search "greed", [],
      fields: [:name, :color],
      misspellings: { fields: { name: false, color: true } }
  end

  def test_unspecified_field_uses_edit_distance_one
    store [{name: "Bingo", color: "blue"}]
    assert_search "bin", [],
      fields: [:name, :color],
      misspellings: { fields: { color: { edit_distance: 2 } } }
    assert_search "bingooo", [],
      fields: [:name, :color],
      misspellings: { fields: { color: { edit_distance: 2 } } }
    assert_search "mango", [],
      fields: [:name, :color],
      misspellings: { fields: { color: { edit_distance: 2 } } }
    assert_search "bing", ["Bingo"],
      fields: [:name, :color],
      misspellings: { fields: { color: { edit_distance: 2 } } }
  end

  def test_field_uses_specified_edit_distance
    store [{name: "Bingo", color: "blue"}]
    assert_search "bl", ["Bingo"],
      fields: [:name, :color],
      misspellings: { fields: { color: { edit_distance: 2 } } }
    assert_search "blueee", ["Bingo"],
      fields: [:name, :color],
      misspellings: { fields: { color: { edit_distance: 2 } } }
    assert_search "blow", ["Bingo"],
      fields: [:name, :color],
      misspellings: { fields: { color: { edit_distance: 2 } } }
  end

  def test_misspelling_zucchini_transposition
    store [{name: "zucchini", color: "green"}]
    assert_search "zuccihni", [],
      fields: [:name, :color],
      misspellings: { fields: { name: {transpositions: false} } }
    assert_search "grene", ["zucchini"],
      fields: [:name, :color],
      misspellings: { fields: { name: {transpositions: false} } }
  end

  def test_misspellings_transposition_combination
    store [{name: "zucchini", color: "green"}]
    options = {
      fields: [:name, :color],
      misspellings: {
        transpositions: false,
        fields: {color: {transpositions: true}}
      }
    }
    assert_search "zuccihni", [], options
    assert_search "greene", ["zucchini"], options
  end

  def test_misspellings_word_start
    store_names ["Sriracha"]
    assert_search "siracha", ["Sriracha"],
      fields: [{name: :word_start}],
      misspellings: { fields: { name: true } }
  end

  def test_misspellings_fields_and_transpositions
    store [{name: "Sriracha", color: "green"}]
    options = {
      fields: [{name: :word_start}],
      misspellings: {
        transpositions: false,
        fields: { name: true }
      }
    }
    assert_search "grene", [], options
    assert_search "srircaha", ["Sriracha"], options
  end

  def test_misspellings_fields_and_edit_distance
    store [{name: "Sriracha", color: "green"}]
    options = {
      fields: [:name, :color],
      misspellings: {
        edit_distance: 2,
        fields: { name: true }
      }
    }
    assert_search "greennn", ["Sriracha"], options
    assert_search "srirachaaa", [], options
    assert_search "siracha", ["Sriracha"], options
  end

  def text_misspellings_fields_requires_explicit_search_fields
    store_names ["Sriracha"]
    assert_raises(ArgumentError) do
      assert_search "siracha", ["Sriracha"],
        misspellings: { fields: { name: false } }
    end
  end
end
