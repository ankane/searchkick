require_relative "test_helper"

class GeoShapeTest < Minitest::Test
  def setup
    setup_region
    store [
      {
        name: "Region A",
        text: "The witch had a cat",
        territory: {
          type: "polygon",
          coordinates: [[[30, 40], [35, 45], [40, 40], [40, 30], [30, 30], [30, 40]]]
        }
      },
      {
        name: "Region B",
        text: "and a very tall hat",
        territory: {
          type: "polygon",
          coordinates: [[[50, 60], [55, 65], [60, 60], [60, 50], [50, 50], [50, 60]]]
        }
      },
      {
        name: "Region C",
        text: "and long ginger hair which she wore in a plait",
        territory: {
          type: "polygon",
          coordinates: [[[10, 20], [15, 25], [20, 20], [20, 10], [10, 10], [10, 20]]]
        }
      }
    ]
  end

  def test_envelope
    assert_search "*", ["Region A"], {
      where: {
        territory: {
          geo_shape: {
            type: "envelope",
            coordinates: [[28, 42], [32, 38]]
          }
        }
      }
    }
  end

  def test_polygon
    assert_search "*", ["Region A"], {
      where: {
        territory: {
          geo_shape: {
            type: "polygon",
            coordinates: [[[38, 42], [42, 42], [42, 38], [38, 38], [38, 42]]]
          }
        }
      }
    }
  end

  def test_multipolygon
    assert_search "*", ["Region A", "Region B"], {
      where: {
        territory: {
          geo_shape: {
            type: "multipolygon",
            coordinates: [
              [[[38, 42], [42, 42], [42, 38], [38, 38], [38, 42]]],
              [[[58, 62], [62, 62], [62, 58], [58, 58], [58, 62]]]
            ]
          }
        }
      }
    }
  end

  def test_disjoint
    assert_search "*", ["Region B", "Region C"], {
      where: {
        territory: {
          geo_shape: {
            type: "envelope",
            relation: "disjoint",
            coordinates: [[28, 42], [32, 38]]
          }
        }
      }
    }
  end

  def test_within
    assert_search "*", ["Region A"], {
      where: {
        territory: {
          geo_shape: {
            type: "envelope",
            relation: "within",
            coordinates: [[20, 50], [50, 20]]
          }
        }
      }
    }
  end

  def test_search_match
    assert_search "witch", ["Region A"], {
      where: {
        territory: {
          geo_shape: {
            type: "envelope",
            coordinates: [[28, 42], [32, 38]]
          }
        }
      }
    }
  end

  def test_search_no_match
    assert_search "ginger hair", [], {
      where: {
        territory: {
          geo_shape: {
            type: "envelope",
            coordinates: [[28, 42], [32, 38]]
          }
        }
      }
    }
  end

  def test_latlon
    assert_search "*", ["Region A"], {
      where: {
        territory: {
          geo_shape: {
            type: "envelope",
            coordinates: [{lat: 42, lon: 28}, {lat: 38, lon: 32}]
          }
        }
      }
    }
  end

  def default_model
    Region
  end
end
