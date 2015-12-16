require_relative "test_helper"

class CallbacksTest < Minitest::Test
  def test_true_create
    Searchkick.callbacks(true) do
      store_names ["Product A", "Product B"]
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product B"]
  end

  def test_false_create
    Searchkick.callbacks(false) do
      store_names ["Product A", "Product B"]
    end
    Product.searchkick_index.refresh
    assert_search "product", []
  end

  def test_bulk_create
    Searchkick.callbacks(:bulk) do
      store_names ["Product A", "Product B"]
    end
    Product.searchkick_index.refresh
    assert_search "product", ["Product A", "Product B"]
  end
end
