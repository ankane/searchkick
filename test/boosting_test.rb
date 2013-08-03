require_relative "test_helper"

class TestBoosting < Minitest::Unit::TestCase

  # conversions

  def test_conversions
    store [
      {name: "Tomato A", conversions: {"tomato" => 1}},
      {name: "Tomato B", conversions: {"tomato" => 2}},
      {name: "Tomato C", conversions: {"tomato" => 3}}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"]
  end

  def test_conversions_stemmed
    store [
      {name: "Tomato A", conversions: {"tomato" => 1, "tomatos" => 1, "Tomatoes" => 1}},
      {name: "Tomato B", conversions: {"tomato" => 2}}
    ]
    assert_order "tomato", ["Tomato A", "Tomato B"]
  end

  # global boost

  def test_boost
    store [
      {name: "Organic Tomato A"},
      {name: "Tomato B", orders_count: 10}
    ]
    assert_order "tomato", ["Tomato B", "Organic Tomato A"], boost: "orders_count"
  end

  def test_boost_zero
    store [
      {name: "Zero Boost", orders_count: 0}
    ]
    assert_order "zero", ["Zero Boost"], boost: "orders_count"
  end

end
