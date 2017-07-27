require_relative "test_helper"

class MultiSearchTest < Minitest::Test
  def test_basic
    store_names ["Product A"]
    store_names ["Store A"], Store
    products = Product.search("*", execute: false)
    stores = Store.search("*", execute: false)
    Searchkick.multi_search([products, stores])
    assert_equal ["Product A"], products.map(&:name)
    assert_equal ["Store A"], stores.map(&:name)
  end

  def test_error
    store_names ["Product A"]
    products = Product.search("*", execute: false)
    stores = Store.search("*", order: [:bad_field], execute: false)
    Searchkick.multi_search([products, stores])
    assert !products.error
    assert stores.error
  end

  def test_misspellings_below_unmet
    store_names ["Product A"]
    store_names ["Store A"], Store
    stores = Store.search("Stre A", misspellings: { below: 2 }, execute: false)
    Searchkick.multi_search([stores])
    assert_equal ["Store A"], stores.map(&:name)
  end
end
