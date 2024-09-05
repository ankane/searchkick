require_relative "test_helper"

class PartialReindexTest < Minitest::Test
  def test_relation_inline
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
    Product.searchkick_index.refresh

    # index not updated
    assert_search "hi", ["Hi"], fields: [:name], load: false
    assert_search "blue", ["Hi"], fields: [:color], load: false

    # partial reindex
    Product.reindex(:search_name)

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false
  end

  def test_record_inline
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
    Product.searchkick_index.refresh

    # index not updated
    assert_search "hi", ["Hi"], fields: [:name], load: false
    assert_search "blue", ["Hi"], fields: [:color], load: false

    product.reindex(:search_name, refresh: true)

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false
  end

  def test_record_async
    product = Product.create!(name: "Hi")
    product.reindex(:search_data, mode: :async)
  end

  def test_relation_missing
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.searchkick_index.remove(product)

    error = assert_raises(Searchkick::ImportError) do
      Product.reindex(:search_name)
    end
    assert_match "document missing", error.message
  end

  def test_record_missing
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.searchkick_index.remove(product)

    error = assert_raises(Searchkick::ImportError) do
      product.reindex(:search_name)
    end
    assert_match "document missing", error.message
  end
end
