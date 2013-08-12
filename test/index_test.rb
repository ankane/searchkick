require_relative "test_helper"

class TestIndex < Minitest::Unit::TestCase

  def test_clean_indices
    old_index = Tire::Index.new("products_development_20130801000000")
    different_index = Tire::Index.new("items_development_20130801000000")

    # create indexes
    old_index.create
    different_index.create

    Product.clean_indices

    assert Product.index.exists?
    assert different_index.exists?
    assert !old_index.exists?
  end

end
