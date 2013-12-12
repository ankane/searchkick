require_relative "test_helper"

class TestBoost < Minitest::Test

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
      {name: "Tomato A"},
      {name: "Tomato B", orders_count: 10},
      {name: "Tomato C", orders_count: 100}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], boost: "orders_count"
  end

  def test_boost_zero
    store [
      {name: "Zero Boost", orders_count: 0}
    ]
    assert_order "zero", ["Zero Boost"], boost: "orders_count"
  end

  def test_conversions_weight
    store [
      {name: "Product Boost", orders_count: 20},
      {name: "Product Conversions", conversions: {"product" => 10}}
    ]
    assert_order "product", ["Product Conversions", "Product Boost"], boost: "orders_count"
  end

  def test_user_id
    store [
      {name: "Tomato A"},
      {name: "Tomato B", user_ids: [1, 2, 3]},
      {name: "Tomato C"},
      {name: "Tomato D"}
    ]
    assert_first "tomato", "Tomato B", user_id: 2
  end

end
