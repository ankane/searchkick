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

  def test_ignore_missing
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.search_index.remove(product)
    Searchkick.stub(:ignore_missing, true) do
      Product.reindex(:search_name)
    end
  end

  # not ideal
  def test_ignore_missing_record
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.search_index.remove(product)
    Searchkick.stub(:ignore_missing, true) do
      product.reindex(:search_name)
    end
  end
end
