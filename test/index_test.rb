require_relative "test_helper"

class TestIndex < Minitest::Unit::TestCase

  def test_clean_indices
    old_index = Tire::Index.new("products_test_20130801000000000")
    different_index = Tire::Index.new("items_test_20130801000000000")

    # create indexes
    old_index.create
    different_index.create

    Product.clean_indices

    assert Product.searchkick_index.exists?
    assert different_index.exists?
    assert !old_index.exists?
  end

  def test_clean_indices_old_format
    old_index = Tire::Index.new("products_test_20130801000000")
    old_index.create

    Product.clean_indices

    assert !old_index.exists?
  end

  def test_mapping
    store_names ["Dollar Tree"], Store
    assert_equal [], Store.search(query: {match: {name: "dollar"}}).map(&:name)
    assert_equal ["Dollar Tree"], Store.search(query: {match: {name: "Dollar Tree"}}).map(&:name)
  end

  def test_custom_mapping_does_not_override_defaults
    store_names ["Dollar Tree"], Store
    assert_equal ["Dollar Tree"], Store.search("dllrtr").map(&:name)
  end

end
