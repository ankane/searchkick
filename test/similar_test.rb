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

  def test_order
    store_names ["Lucerne Milk Chocolate Fat Free", "Clover Fat Free Milk"]
    assert_order "Lucerne Fat Free Chocolate Milk", ["Lucerne Milk Chocolate Fat Free", "Clover Fat Free Milk"], similar: true
  end

  def test_per_page_option
    store_names ["Bag 1", "Bag 2", "Bag 3", "Bag 4", "Bag 5", "Bag 6", "Bag 7"]
    bag_1 = Product.where(name: "Bag 1").first
    assert_equal 6, bag_1.similar(fields: ["name"]).size
    assert_equal 3, bag_1.similar(fields: ["name"], page: 1, per_page: 3).size
    assert_equal 3, bag_1.similar(fields: ["name"], page: 2, per_page: 3).size
  end
end
