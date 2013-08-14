require_relative "test_helper"

class TestSimilar < Minitest::Unit::TestCase

  def test_fields
    store_names ["1% Organic Milk", "2% Organic Milk", "Popcorn"]
    assert_equal ["2% Organic Milk"], Product.find_by(name: "1% Organic Milk").similar(fields: ["name"]).map(&:name)
  end

end
