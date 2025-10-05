require_relative "test_helper"

class PartialReindexTest < Minitest::Test
  def test_record_inline
    store [{name: "Hi", color: "Blue"}]

    # update
    product = Product.first
    product.name = "Bye"
    product.color = "Red"
    Searchkick.callbacks(false) do
      product.save!
    end

    # partial reindex
    product.reindex(:search_name, refresh: true)

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false
  end

  def test_record_async
    store [{name: "Hi", color: "Blue"}]

    # update
    product = Product.first
    product.name = "Bye"
    product.color = "Red"
    Searchkick.callbacks(false) do
      product.save!
    end

    # partial reindex
    perform_enqueued_jobs do
      product.reindex(:search_name, mode: :async)
    end
    Product.searchkick_index.refresh

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false
  end

  def test_record_queue
    product = Product.create!(name: "Hi")
    error = assert_raises(Searchkick::Error) do
      product.reindex(:search_name, mode: :queue)
    end
    assert_equal "Partial reindex not supported with queue option", error.message
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

  def test_relation_inline
    store [{name: "Hi", color: "Blue"}]

    # update
    product = Product.first
    product.name = "Bye"
    product.color = "Red"
    Searchkick.callbacks(false) do
      product.save!
    end

    # partial reindex
    Product.reindex(:search_name)

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false

    # scope
    Product.reindex(:search_name, scope: :all)
  end

  def test_relation_async
    store [{name: "Hi", color: "Blue"}]

    # update
    product = Product.first
    product.name = "Bye"
    product.color = "Red"
    Searchkick.callbacks(false) do
      product.save!
    end

    # partial reindex
    perform_enqueued_jobs do
      Product.reindex(:search_name, mode: :async)
    end

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false
  end

  def test_relation_queue
    product = Product.create!(name: "Hi")
    error = assert_raises(Searchkick::Error) do
      Product.reindex(:search_name, mode: :queue)
    end
    assert_equal "Partial reindex not supported with queue option", error.message
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
end
