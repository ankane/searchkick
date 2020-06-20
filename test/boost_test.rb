require_relative "test_helper"

class BoostTest < Minitest::Test
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

  # fields

  def test_fields
    store [
      {name: "Red", color: "White"},
      {name: "White", color: "Red Red Red"}
    ]
    assert_order "red", ["Red", "White"], fields: ["name^10", "color"]
  end

  def test_fields_decimal
    store [
      {name: "Red", color: "White"},
      {name: "White", color: "Red Red Red"}
    ]
    assert_order "red", ["Red", "White"], fields: ["name^10.5", "color"]
  end

  def test_fields_word_start
    store [
      {name: "Red", color: "White"},
      {name: "White", color: "Red Red Red"}
    ]
    assert_order "red", ["Red", "White"], fields: [{"name^10" => :word_start}, "color"]
  end

  # for issue #855
  def test_fields_apostrophes
    store_names ["Valentine's Day Special"]
    assert_search "Valentines", ["Valentine's Day Special"], fields: ["name^5"]
    assert_search "Valentine's", ["Valentine's Day Special"], fields: ["name^5"]
    assert_search "Valentine", ["Valentine's Day Special"], fields: ["name^5"]
  end

  def test_boost_by
    store [
      {name: "Tomato A"},
      {name: "Tomato B", orders_count: 10},
      {name: "Tomato C", orders_count: 100}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], boost_by: [:orders_count]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], boost_by: {orders_count: {factor: 10}}
  end

  def test_boost_by_missing
    store [
      {name: "Tomato A"},
      {name: "Tomato B", orders_count: 10},
    ]

    assert_order "tomato", ["Tomato A", "Tomato B"], boost_by: {orders_count: {missing: 100}}
  end

  def test_boost_by_boost_mode_multiply
    store [
      {name: "Tomato A", found_rate: 0.9},
      {name: "Tomato B"},
      {name: "Tomato C", found_rate: 0.5}
    ]

    assert_order "tomato", ["Tomato B", "Tomato A", "Tomato C"], boost_by: {found_rate: {boost_mode: "multiply"}}
  end

  def test_boost_where
    store [
      {name: "Tomato A"},
      {name: "Tomato B", user_ids: [1, 2]},
      {name: "Tomato C", user_ids: [3]}
    ]
    assert_first "tomato", "Tomato B", boost_where: {user_ids: 2}
    assert_first "tomato", "Tomato B", boost_where: {user_ids: 1..2}
    assert_first "tomato", "Tomato B", boost_where: {user_ids: [1, 4]}
    assert_first "tomato", "Tomato B", boost_where: {user_ids: {value: 2, factor: 10}}
    assert_first "tomato", "Tomato B", boost_where: {user_ids: {value: [1, 4], factor: 10}}
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], boost_where: {user_ids: [{value: 1, factor: 10}, {value: 3, factor: 20}]}
  end

  def test_boost_where_negative_boost
    store [
      {name: "Tomato A"},
      {name: "Tomato B", user_ids: [2]},
      {name: "Tomato C", user_ids: [2]}
    ]
    assert_first "tomato", "Tomato A", boost_where: {user_ids: {value: 2, factor: 0.5}}
  end

  def test_boost_by_recency
    store [
      {name: "Article 1", created_at: 2.days.ago},
      {name: "Article 2", created_at: 1.day.ago},
      {name: "Article 3", created_at: Time.now}
    ]
    assert_order "article", ["Article 3", "Article 2", "Article 1"], boost_by_recency: {created_at: {scale: "7d", decay: 0.5}}
  end

  def test_boost_by_recency_origin
    store [
      {name: "Article 1", created_at: 2.days.ago},
      {name: "Article 2", created_at: 1.day.ago},
      {name: "Article 3", created_at: Time.now}
    ]
    assert_order "article", ["Article 1", "Article 2", "Article 3"], boost_by_recency: {created_at: {origin: 2.days.ago, scale: "7d", decay: 0.5}}
  end

  def test_boost_by_distance
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000},
      {name: "San Marino", latitude: 43.9333, longitude: 12.4667}
    ]
    assert_order "san", ["San Francisco", "San Antonio", "San Marino"], boost_by_distance: {field: :location, origin: [37, -122], scale: "1000mi"}
  end

  def test_boost_by_distance_hash
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000},
      {name: "San Marino", latitude: 43.9333, longitude: 12.4667}
    ]
    assert_order "san", ["San Francisco", "San Antonio", "San Marino"], boost_by_distance: {field: :location, origin: {lat: 37, lon: -122}, scale: "1000mi"}
  end

  def test_boost_by_distance_v2
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000},
      {name: "San Marino", latitude: 43.9333, longitude: 12.4667}
    ]
    assert_order "san", ["San Francisco", "San Antonio", "San Marino"], boost_by_distance: {location: {origin: [37, -122], scale: "1000mi"}}
  end

  def test_boost_by_distance_v2_hash
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000},
      {name: "San Marino", latitude: 43.9333, longitude: 12.4667}
    ]
    assert_order "san", ["San Francisco", "San Antonio", "San Marino"], boost_by_distance: {location: {origin: {lat: 37, lon: -122}, scale: "1000mi"}}
  end

  def test_boost_by_distance_v2_factor
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167, found_rate: 0.1},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000, found_rate: 0.99},
      {name: "San Marino", latitude: 43.9333, longitude: 12.4667, found_rate: 0.2}
    ]

    assert_order "san", ["San Antonio","San Francisco", "San Marino"], boost_by: {found_rate: {factor: 100}}, boost_by_distance: {location: {origin: [37, -122], scale: "1000mi"}}
    assert_order "san", ["San Francisco", "San Antonio", "San Marino"], boost_by: {found_rate: {factor: 100}}, boost_by_distance: {location: {origin: [37, -122], scale: "1000mi", factor: 100}}
  end

  def test_boost_by_indices
    skip if cequel?

    store_names ["Rex"], Animal
    store_names ["Rexx"], Product

    assert_order "Rex", ["Rexx", "Rex"], {models: [Animal, Product], indices_boost: {Animal => 1, Product => 200}, fields: [:name]}, Searchkick
  end
end
