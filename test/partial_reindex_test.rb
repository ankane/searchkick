require_relative "test_helper"

class PartialReindexTest < Minitest::Test
  def test_class_method
    store [{name: "Hi", color: "Blue"}]

    # normal search
    assert_search "hi", ["Hi"], fields: [:name], load: false
    assert_search "blue", ["Hi"], fields: [:color], load: false

    # update
    product = Product.first
    product.name = "Bye"
    product.color = "Red"
    Searchkick.callbacks(false) do
      product.save!
    end
    Product.search_index.refresh

    # index not updated
    assert_search "hi", ["Hi"], fields: [:name], load: false
    assert_search "blue", ["Hi"], fields: [:color], load: false

    # partial reindex
    Product.reindex(:search_name)

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false
  end

  def test_instance_method
    store [{name: "Hi", color: "Blue"}]

    # normal search
    assert_search "hi", ["Hi"], fields: [:name], load: false
    assert_search "blue", ["Hi"], fields: [:color], load: false

    # update
    product = Product.first
    product.name = "Bye"
    product.color = "Red"
    Searchkick.callbacks(false) do
      product.save!
    end
    Product.search_index.refresh

    # index not updated
    assert_search "hi", ["Hi"], fields: [:name], load: false
    assert_search "blue", ["Hi"], fields: [:color], load: false

    product.reindex(:search_name, refresh: true)

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false
  end

  def test_instance_method_async
    product = Product.create!(name: "Hi")
    product.reindex(:search_data, mode: :async)
  end

  def test_missing
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.search_index.remove(product)
    error = assert_raises(Searchkick::ImportError) do
      product.reindex(:search_name)
    end
    assert_match "document missing", error.message
  end

  def test_allow_missing_inline
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.search_index.remove(product)

    error = assert_raises(Searchkick::ImportError) do
      Product.reindex(:search_name)
    end
    assert_match "document_missing_exception", error.message

    Product.reindex(:search_name, allow_missing: true)
  end

  def test_allow_missing_record
    error = assert_raises(ArgumentError) do
      Product.create!.reindex(:search_name, allow_missing: true)
    end
    assert_equal "unknown keyword: :allow_missing", error.message
  end

  def test_allow_missing_async
    error = assert_raises(Searchkick::Error) do
      Product.reindex(:search_name, allow_missing: true, mode: :async)
    end
    assert_equal "allow_missing only available with :inline mode", error.message
  end

  def test_allow_missing_full
    error = assert_raises(ArgumentError) do
      Product.reindex(allow_missing: true)
    end
    assert_equal "unknown keyword: :allow_missing", error.message
  end
end
