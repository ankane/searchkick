require_relative "test_helper"

class MisspellingsTest < Minitest::Test
  def test_misspellings
    store_names ["abc", "abd", "aee"]
    assert_search "abc", ["abc"], misspellings: false
  end

  def test_misspellings_distance
    store_names ["abbb", "aabb"]
    assert_search "aaaa", ["aabb"], misspellings: {distance: 2}
  end

  def test_misspellings_prefix_length
    store_names ["ap", "api", "apt", "any", "nap", "ah", "ahi"]
    assert_search "ap", ["ap"], misspellings: {prefix_length: 2}
    assert_search "api", ["ap", "api", "apt"], misspellings: {prefix_length: 2}
  end

  def test_misspellings_prefix_length_operator
    store_names ["ap", "api", "apt", "any", "nap", "ah", "aha"]
    assert_search "ap ah", ["ap", "ah"], operator: "or", misspellings: {prefix_length: 2}
    assert_search "api ahi", ["ap", "api", "apt", "ah", "aha"], operator: "or", misspellings: {prefix_length: 2}
  end

  def test_misspellings_fields_operator
    store [
      {name: "red", color: "red"},
      {name: "blue", color: "blue"},
      {name: "cyan", color: "blue green"},
      {name: "magenta", color: "red blue"},
      {name: "green", color: "green"}
    ]
    assert_search "red blue", ["red", "blue", "cyan", "magenta"], operator: "or", fields: ["color"], misspellings: false
  end

  def test_misspellings_below_unmet
    store_names ["abc", "abd", "aee"]
    assert_search "abc", ["abc", "abd"], misspellings: {below: 2}
  end

  def test_misspellings_below_unmet_result
    store_names ["abc", "abd", "aee"]
    assert Product.search("abc", misspellings: {below: 2}).misspellings?
  end

  def test_misspellings_below_met
    store_names ["abc", "abd", "aee"]
    assert_search "abc", ["abc"], misspellings: {below: 1}
  end

  def test_misspellings_below_met_result
    store_names ["abc", "abd", "aee"]
    assert !Product.search("abc", misspellings: {below: 1}).misspellings?
  end
end
