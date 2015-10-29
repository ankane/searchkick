require_relative "test_helper"

class SimilarTest < Minitest::Test
  def test_similar
    store_names ["Annie's Naturals Organic Shiitake & Sesame Dressing"]
    assert_search "Annie's Naturals Shiitake & Sesame Vinaigrette", ["Annie's Naturals Organic Shiitake & Sesame Dressing"], similar: true
  end

  def test_fields
    store_names ["1% Organic Milk", "2% Organic Milk", "Popcorn"]
    assert_equal ["2% Organic Milk"], Product.where(name: "1% Organic Milk").first.similar(fields: ["name"]).map(&:name)
  end

  def test_order
    store_names ["Lucerne Milk Chocolate Fat Free", "Clover Fat Free Milk"]
    assert_order "Lucerne Fat Free Chocolate Milk", ["Lucerne Milk Chocolate Fat Free", "Clover Fat Free Milk"], similar: true
  end
end
