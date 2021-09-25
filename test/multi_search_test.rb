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

  def test_methods
    result = Product.search("*")
    query = Product.search("*", execute: false)
    assert_empty(result.methods - query.methods)
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
    products = Product.search("abc", misspellings: {below: 5}, execute: false)
    Searchkick.multi_search([products])
    assert_equal ["abc", "abd"], products.map(&:name)
  end

  def test_query_error
    products = Product.search("*", order: {bad_column: :asc}, execute: false)
    Searchkick.multi_search([products])
    assert products.error
    error = assert_raises(Searchkick::Error) { products.results }
    assert_equal error.message, "Query error - use the error method to view it"
  end
end
