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
    store_names ["abc", "abd", "aee"]
    products = Product.search("abc", misspellings: {below: 2}, execute: false)
    Searchkick.multi_search([products])
    assert_equal ["abc"], products.map(&:name)
  end

  def test_misspellings_below_unmet_retry
    store_names ["abc", "abd", "aee"]
    products = Product.search("abc", misspellings: {below: 2}, execute: false)
    Searchkick.multi_search([products], retry_misspellings: true)
    assert_equal ["abc", "abd"], products.map(&:name)
  end
end
