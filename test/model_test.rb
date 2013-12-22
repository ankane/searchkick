require_relative "test_helper"

class TestModel < Minitest::Unit::TestCase

  def test_searchkick_disable
    store_names ["product a"]

    Product.searchkick_disable!
    assert !Product.searchkick_enabled?, 'searchkick has been disabled'

    store_names ["product b"]
    assert_search "product", ["product a"]

    Product.searchkick_enable!
    Product.reindex

    assert_search "product", ["product a", "product b"]
  end

  def test_global_searchkick_disable
    store_names ["product a"]

    Searchkick.disable!
    assert !Searchkick.enabled?, 'searchkick has been disabled'

    store_names ["product b"]
    assert_search "product", ["product a"]

    Searchkick.enable!
    Product.reindex

    assert_search "product", ["product a", "product b"]
  end

end
