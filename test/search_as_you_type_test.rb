require_relative "test_helper"

class SearchAsYouTypeTest < Minitest::Test
  def setup
    Item.destroy_all
  end

  def test_works
    store_names ["Hummus"]
    assert_search "hum", ["Hummus"]
  end

  def default_model
    Item
  end
end
