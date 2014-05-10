require_relative "test_helper"

class TestIndex < Minitest::Unit::TestCase

  def test_clean_indices
    old_index = Searchkick::Index.new("products_test_20130801000000000")
    different_index = Searchkick::Index.new("items_test_20130801000000000")

    old_index.delete if old_index.exists?
    different_index.delete if different_index.exists?

    # create indexes
    old_index.create
    different_index.create

    Product.clean_indices

    assert Product.searchkick_index.exists?
    assert different_index.exists?
    assert !old_index.exists?
  end

  def test_clean_indices_old_format
    old_index = Searchkick::Index.new("products_test_20130801000000")
    old_index.create

    Product.clean_indices

    assert !old_index.exists?
  end

  def test_mapping
    store_names ["Dollar Tree"], Store
    assert_equal [], Store.search(query: {match: {name: "dollar"}}).map(&:name)
    assert_equal ["Dollar Tree"], Store.search(query: {match: {name: "Dollar Tree"}}).map(&:name)
  end

  def test_record_not_found
    store_names ["Product A", "Product B"]
    Product.where(name: "Product A").delete_all
    assert_search "product", ["Product B"]
  end

  if defined?(ActiveRecord)

    def test_transaction
      Product.transaction do
        store_names ["Product A"]
        raise ActiveRecord::Rollback
      end

      assert_search "product", []
    end

  end

end
