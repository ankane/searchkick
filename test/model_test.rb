require_relative "test_helper"

class ModelTest < Minitest::Test
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

  def test_search_data_matches
    store_names ["Product A"]
    metadata_keys = %w(_index _type _id _score _routing id indexed_at)
    expected_result_keys = Product.last.search_data.to_hash.stringify_keys.keys + metadata_keys
    search_result_keys   = Product.search("Product A", load: false).first.to_hash.keys
    assert_equal expected_result_keys.sort, search_result_keys.sort
  end

  def test_indexed_at
    current_time = Time.now
    Time.stub :now, current_time do
      store_names ["Product A"]
      indexed_at = Product.search("Product A", load: false).first.to_hash['indexed_at']
      assert_equal indexed_at, current_time.strftime('%FT%T.%LZ')
    end
  end
end
