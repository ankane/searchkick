require_relative "test_helper"

class ConversionsTest < Minitest::Test
  def setup
    super
    setup_speaker
  end

  def test_conversions
    store [
      {name: "Tomato A", conversions: {"tomato" => 1}},
      {name: "Tomato B", conversions: {"tomato" => 2}},
      {name: "Tomato C", conversions: {"tomato" => 3}}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"]
    assert_equal_scores "tomato", conversions: false
  end

  def test_conversions_v2
    store [
      {name: "Tomato A", conversions_v2: {"tomato" => 1}},
      {name: "Tomato B", conversions_v2: {"tomato" => 2}},
      {name: "Tomato C", conversions_v2: {"tomato" => 3}}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], conversions_v2: [:conversions_v2]
  end

  def test_conversions_v2_space
    store [
      {name: "Tomato A", conversions_v2: {"tomato juice" => 1}},
      {name: "Tomato B", conversions_v2: {"tomato juice" => 2}},
      {name: "Tomato C", conversions_v2: {"tomato juice" => 3}}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], conversions_v2: [:conversions_v2], conversions_term: "tomato juice"
  end

  def test_conversions_v2_dot
    store [
      {name: "Tomato A", conversions_v2: {"tomato.juice" => 1}},
      {name: "Tomato B", conversions_v2: {"tomato.juice" => 2}},
      {name: "Tomato C", conversions_v2: {"tomato.juice" => 3}}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], conversions_v2: [:conversions_v2], conversions_term: "tomato.juice"
  end

  def test_conversions_v2_zero
    error = assert_raises(Searchkick::ImportError) do
      store [{name: "Tomato A", conversions_v2: {"tomato" => 0}}]
    end
    assert_match "must be a positive normal float", error.message
  end

  def test_conversions_v2_score
    store [
      {name: "Tomato A", conversions: {"tomato" => 1}, conversions_v2: {"tomato" => 1}},
      {name: "Tomato B", conversions: {"tomato" => 2}, conversions_v2: {"tomato" => 2}},
      {name: "Tomato C", conversions: {"tomato" => 3}, conversions_v2: {"tomato" => 3}}
    ]
    scores = Product.search("tomato", conversions_v2: false, load: false).map(&:_score)
    scores_v2 = Product.search("tomato", conversions: false, conversions_v2: "conversions_v2", load: false).map(&:_score)
    assert_equal scores, scores_v2
  end

  def test_multiple_conversions
    store [
      {name: "Speaker A", conversions_a: {"speaker" => 1}, conversions_b: {"speaker" => 6}},
      {name: "Speaker B", conversions_a: {"speaker" => 2}, conversions_b: {"speaker" => 5}},
      {name: "Speaker C", conversions_a: {"speaker" => 3}, conversions_b: {"speaker" => 4}}
    ], Speaker

    assert_equal_scores "speaker", {conversions: false}, Speaker
    assert_equal_scores "speaker", {}, Speaker
    assert_equal_scores "speaker", {conversions: ["conversions_a", "conversions_b"]}, Speaker
    assert_equal_scores "speaker", {conversions: ["conversions_b", "conversions_a"]}, Speaker
    assert_order "speaker", ["Speaker C", "Speaker B", "Speaker A"], {conversions: "conversions_a"}, Speaker
    assert_order "speaker", ["Speaker A", "Speaker B", "Speaker C"], {conversions: "conversions_b"}, Speaker
  end

  def test_multiple_conversions_with_boost_term
    store [
      {name: "Speaker A", conversions_a: {"speaker" => 4, "speaker_1" => 1}},
      {name: "Speaker B", conversions_a: {"speaker" => 3, "speaker_1" => 2}},
      {name: "Speaker C", conversions_a: {"speaker" => 2, "speaker_1" => 3}},
      {name: "Speaker D", conversions_a: {"speaker" => 1, "speaker_1" => 4}}
    ], Speaker

    assert_order "speaker", ["Speaker A", "Speaker B", "Speaker C", "Speaker D"], {conversions: "conversions_a"}, Speaker
    assert_order "speaker", ["Speaker D", "Speaker C", "Speaker B", "Speaker A"], {conversions: "conversions_a", conversions_term: "speaker_1"}, Speaker
  end

  def test_conversions_case
    store [
      {name: "Tomato A", conversions: {"tomato" => 1, "TOMATO" => 1, "tOmAtO" => 1}},
      {name: "Tomato B", conversions: {"tomato" => 2}}
    ]
    assert_order "tomato", ["Tomato A", "Tomato B"]
  end

  def test_conversions_weight
    Product.reindex
    store [
      {name: "Product Boost", orders_count: 20},
      {name: "Product Conversions", conversions: {"product" => 10}}
    ]
    assert_order "product", ["Product Conversions", "Product Boost"], boost: "orders_count"
  end
end
