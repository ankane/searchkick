require "pp"
require_relative "test_helper"

class GeoShapeTest < Minitest::Test

  def test_geo_shape
    regions = [
      {name: "Region A", text: "The witch had a cat", territory: "30,40,35,45,40,40,40,30,30,30,30,40"},
      {name: "Region B", text: "and a very tall hat", territory: "50,60,55,65,60,60,60,50,50,50,50,60"},
      {name: "Region C", text: "and long ginger hair which she wore in a plait.",  territory: "10,20,15,25,20,20,20,10,10,10,10,20"},
    ]
    store regions, Region

    # circle
    assert_search "*", ["Region A"], {
      where: {
        territory: {
          geo_shape: {
            type: "circle",
            coordinates: {lat: 28.0, lon: 38.0},
            radius: "444000m"
          }
        }
      }
    }, Region

    # envelope
    assert_search "*", ["Region A"], {
      where: {
        territory: {
          geo_shape: {
            type: "envelope",
            coordinates: [[28, 42], [32, 38]]
          }
        }
      }
    }, Region

    # envelope as corners
    assert_search "*", ["Region A"], {
      where: {
        territory: {
          geo_shape: {
            type: "envelope",
            top_left: {lat: 42.0, lon: 28.0},
            bottom_right: {lat: 38.0, lon: 32.0}
          }
        }
      }
    }, Region

    # polygon
    assert_search "*", ["Region A"], {
      where: {
        territory: {
          geo_shape: {
            type: "polygon",
            coordinates: [[[38, 42], [42, 42], [42, 38], [38, 38], [38, 42]]]
          }
        }
      }
    }, Region

    # multipolygon
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
    }, Region

    # disjoint
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
    }, Region

    # within
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
    }, Region

    # with search
    assert_search "witch", ["Region A"], {
      where: {
        territory: {
          geo_shape: {
            type: "envelope",
            coordinates: [[28, 42], [32, 38]]
          }
        }
      }
    }, Region

    assert_search "ginger hair", [], {
      where: {
        territory: {
          geo_shape: {
            type: "envelope",
            coordinates: [[28, 42], [32, 38]]
          }
        }
      }
    }, Region
  end

  def test_geo_shape_contains
    skip if elasticsearch_below22?

    assert_search "*", ["Region A"], {
      where: {
        territory: {
          geo_shape: {
            type: "envelope",
            relation: "contains",
            coordinates: [[32, 33], [33, 32]]
          }
        }
      }
    }, Region

  end
end
