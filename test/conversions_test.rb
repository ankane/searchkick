require_relative "test_helper"

class ConversionsTest < Minitest::Test
  def setup
    super
    setup_speaker
  end

  def test_v1
    store [
      {name: "Tomato A", conversions: {"tomato" => 1}},
      {name: "Tomato B", conversions: {"tomato" => 2}},
      {name: "Tomato C", conversions: {"tomato" => 3}}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"]
    assert_order "TOMATO", ["Tomato C", "Tomato B", "Tomato A"]
    assert_equal_scores "tomato", conversions_v1: false
  end

  def test_v1_case
    store [
      {name: "Tomato A", conversions: {"tomato" => 1, "TOMATO" => 1, "tOmAtO" => 1}},
      {name: "Tomato B", conversions: {"tomato" => 2}}
    ]
    assert_order "tomato", ["Tomato A", "Tomato B"]
  end

  def test_v1_case_sensitive
    with_options(case_sensitive: true) do
      store [
        {name: "Tomato A", conversions: {"Tomato" => 1, "TOMATO" => 1, "tOmAtO" => 1}},
        {name: "Tomato B", conversions: {"Tomato" => 2}}
      ]
      assert_order "Tomato", ["Tomato B", "Tomato A"]
    end
  ensure
    Product.reindex
  end

  def test_v1_weight
    Product.reindex
    store [
      {name: "Product Boost", orders_count: 20},
      {name: "Product Conversions", conversions: {"product" => 10}}
    ]
    assert_order "product", ["Product Conversions", "Product Boost"], boost: "orders_count"
  end

  def test_v1_multiple_conversions
    store [
      {name: "Speaker A", conversions_a: {"speaker" => 1}, conversions_b: {"speaker" => 6}},
      {name: "Speaker B", conversions_a: {"speaker" => 2}, conversions_b: {"speaker" => 5}},
      {name: "Speaker C", conversions_a: {"speaker" => 3}, conversions_b: {"speaker" => 4}}
    ], Speaker

    assert_equal_scores "speaker", {conversions_v1: false}, Speaker
    assert_equal_scores "speaker", {}, Speaker
    assert_equal_scores "speaker", {conversions_v1: ["conversions_a", "conversions_b"]}, Speaker
    assert_equal_scores "speaker", {conversions_v1: ["conversions_b", "conversions_a"]}, Speaker
    assert_order "speaker", ["Speaker C", "Speaker B", "Speaker A"], {conversions_v1: "conversions_a"}, Speaker
    assert_order "speaker", ["Speaker A", "Speaker B", "Speaker C"], {conversions_v1: "conversions_b"}, Speaker
  end

  def test_v1_multiple_conversions_with_boost_term
    store [
      {name: "Speaker A", conversions_a: {"speaker" => 4, "speaker_1" => 1}},
      {name: "Speaker B", conversions_a: {"speaker" => 3, "speaker_1" => 2}},
      {name: "Speaker C", conversions_a: {"speaker" => 2, "speaker_1" => 3}},
      {name: "Speaker D", conversions_a: {"speaker" => 1, "speaker_1" => 4}}
    ], Speaker

    assert_order "speaker", ["Speaker A", "Speaker B", "Speaker C", "Speaker D"], {conversions_v1: "conversions_a"}, Speaker
    assert_order "speaker", ["Speaker D", "Speaker C", "Speaker B", "Speaker A"], {conversions_v1: "conversions_a", conversions_term: "speaker_1"}, Speaker
  end

  def test_v2
    store [
      {name: "Tomato A", conversions_v2: {"tomato" => 1}},
      {name: "Tomato B", conversions_v2: {"tomato" => 2}},
      {name: "Tomato C", conversions_v2: {"tomato" => 3}}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], conversions_v2: true
    assert_order "TOMATO", ["Tomato C", "Tomato B", "Tomato A"], conversions_v2: true
    assert_equal_scores "tomato", conversions_v2: false
  end

  def test_v2_case
    store [
      {name: "Tomato A", conversions_v2: {"tomato" => 1, "TOMATO" => 1, "tOmAtO" => 1}},
      {name: "Tomato B", conversions_v2: {"tomato" => 2}}
    ]
    assert_order "tomato", ["Tomato A", "Tomato B"], conversions_v2: true
  end

  def test_v2_case_sensitive
    with_options(case_sensitive: true) do
      store [
        {name: "Tomato A", conversions_v2: {"Tomato" => 1, "TOMATO" => 1, "tOmAtO" => 1}},
        {name: "Tomato B", conversions_v2: {"Tomato" => 2}}
      ]
      assert_order "Tomato", ["Tomato B", "Tomato A"], conversions_v2: true
    end
  ensure
    Product.reindex
  end

  def test_v2_weight
    Product.reindex
    store [
      {name: "Product Boost", orders_count: 20},
      {name: "Product Conversions", conversions_v2: {"product" => 10}}
    ]
    assert_order "product", ["Product Conversions", "Product Boost"], conversions_v2: true, boost: "orders_count"
  end

  def test_v2_space
    store [
      {name: "Tomato A", conversions_v2: {"tomato juice" => 1}},
      {name: "Tomato B", conversions_v2: {"tomato juice" => 2}},
      {name: "Tomato C", conversions_v2: {"tomato juice" => 3}}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], conversions_v2: {term: "tomato juice"}
  end

  def test_v2_dot
    store [
      {name: "Tomato A", conversions_v2: {"tomato.juice" => 1}},
      {name: "Tomato B", conversions_v2: {"tomato.juice" => 2}},
      {name: "Tomato C", conversions_v2: {"tomato.juice" => 3}}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], conversions_v2: {term: "tomato.juice"}
  end

  def test_v2_unicode
    store [
      {name: "Tomato A", conversions_v2: {"喰らう" => 1}},
      {name: "Tomato B", conversions_v2: {"喰らう" => 2}},
      {name: "Tomato C", conversions_v2: {"喰らう" => 3}}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], conversions_v2: {term: "喰らう"}
  end

  def test_v2_score
    store [
      {name: "Tomato A", conversions: {"tomato" => 1}, conversions_v2: {"tomato" => 1}},
      {name: "Tomato B", conversions: {"tomato" => 2}, conversions_v2: {"tomato" => 2}},
      {name: "Tomato C", conversions: {"tomato" => 3}, conversions_v2: {"tomato" => 3}}
    ]
    scores = Product.search("tomato", conversions_v2: false, load: false).map(&:_score)
    scores_v2 = Product.search("tomato", conversions_v1: false, conversions_v2: true, load: false).map(&:_score)
    assert_equal scores, scores_v2
  end

  def test_v2_factor
    store [
      {name: "Tomato A", conversions: {"tomato" => 1}, conversions_v2: {"tomato" => 1}},
      {name: "Tomato B", conversions: {"tomato" => 2}, conversions_v2: {"tomato" => 2}},
      {name: "Tomato C", conversions: {"tomato" => 3}, conversions_v2: {"tomato" => 3}}
    ]
    scores = Product.search("tomato", conversions_v1: false, conversions_v2: true, load: false).map(&:_score)
    scores2 = Product.search("tomato", conversions_v1: false, conversions_v2: {factor: 3}, load: false).map(&:_score)
    diffs = scores.zip(scores2).map { |a, b| b - a }
    assert_in_delta 6, diffs[0]
    assert_in_delta 4, diffs[1]
    assert_in_delta 2, diffs[2]
  end

  def test_v2_no_tokenization
    store [
      {name: "Tomato A"},
      {name: "Tomato B", conversions_v2: {"tomato juice" => 2}},
      {name: "Tomato C", conversions_v2: {"tomato vine" => 3}}
    ]
    assert_equal_scores "tomato", conversions_v2: true
  end

  def test_v2_max_conversions
    conversions = 66000.times.to_h { |i| ["term#{i}", 1] }
    store [{name: "Tomato A", conversions_v2: conversions}]

    conversions.merge!(1000.times.to_h { |i| ["term#{conversions.size + i}", 1] })
    assert_raises(Searchkick::ImportError) do
      store [{name: "Tomato B", conversions_v2: conversions}]
    end
  end

  def test_v2_max_length
    store [{name: "Tomato A", conversions_v2: {"a"*32766 => 1}}]

    assert_raises(Searchkick::ImportError) do
      store [{name: "Tomato B", conversions_v2: {"a"*32767 => 1}}]
    end
  end

  def test_v2_zero
    error = assert_raises(Searchkick::ImportError) do
      store [{name: "Tomato A", conversions_v2: {"tomato" => 0}}]
    end
    assert_match "must be a positive normal float", error.message
  end

  def test_v2_partial_reindex
    store [
      {name: "Tomato A", conversions_v2: {"tomato" => 1}},
      {name: "Tomato B", conversions_v2: {"tomato" => 2}},
      {name: "Tomato C", conversions_v2: {"tomato" => 3}}
    ]
    Product.reindex(:search_name, refresh: true)
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], conversions_v2: true
  end
end
