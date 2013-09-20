require_relative "test_helper"

class TestSimilar < Minitest::Unit::TestCase

  def test_similar
    store_names ["Annie's Naturals Organic Shiitake & Sesame Dressing"]
    assert_search "Annie's Naturals Shiitake & Sesame Vinaigrette", ["Annie's Naturals Organic Shiitake & Sesame Dressing"], similar: true
  end

  def test_fields
    store_names ["1% Organic Milk", "2% Organic Milk", "Popcorn"]
    assert_equal ["2% Organic Milk"], Product.where(name: "1% Organic Milk").first.similar(fields: ["name"]).map(&:name)
  end

end
