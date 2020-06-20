require_relative "test_helper"

class CallbacksTest < Minitest::Test
  def test_disable_callbacks_model
    store_names ["product a"]

    Searchkick.callbacks(false) do
      store_names ["product b"]
    end
    assert_search "product", ["product a"]

    Product.reindex

    assert_search "product", ["product a", "product b"]
  end

  def test_disable_callbacks_global
    # make sure callbacks default to on
    assert Searchkick.callbacks?

    store_names ["product a"]

    Searchkick.disable_callbacks
    assert !Searchkick.callbacks?

    store_names ["product b"]
    assert_search "product", ["product a"]

    Searchkick.enable_callbacks
    Product.reindex

    assert_search "product", ["product a", "product b"]
  end
end
