require_relative "test_helper"

class PartialReindexTest < Minitest::Test
  def test_record_inline
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Searchkick.callbacks(false) do
      product.update!(name: "Bye", color: "Red")
    end

    product.reindex(:search_name, refresh: true)

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false
  end

  def test_record_async
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Searchkick.callbacks(false) do
      product.update!(name: "Bye", color: "Red")
    end

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

  def test_record_missing_inline
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.searchkick_index.remove(product)

    error = assert_raises(Searchkick::ImportError) do
      product.reindex(:search_name)
    end
    assert_match "document missing", error.message
  end

  def test_record_on_missing_ignore_inline
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.searchkick_index.remove(product)

    product.reindex(:search_name, on_missing: :ignore)
    Searchkick.callbacks(:bulk) do
      product.reindex(:search_name, on_missing: :ignore)
    end
  end

  def test_record_missing_async
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.searchkick_index.remove(product)

    perform_enqueued_jobs do
      error = assert_raises(Searchkick::ImportError) do
        product.reindex(:search_name, mode: :async)
      end
      assert_match "document missing", error.message
    end
  end

  def test_record_on_missing_ignore_async
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.searchkick_index.remove(product)

    perform_enqueued_jobs do
      product.reindex(:search_name, mode: :async, on_missing: :ignore)
    end
  end

  def test_relation_inline
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Searchkick.callbacks(false) do
      product.update!(name: "Bye", color: "Red")
    end

    Product.reindex(:search_name)

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false

    # scope
    Product.reindex(:search_name, scope: :all)
  end

  def test_relation_async
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Searchkick.callbacks(false) do
      product.update!(name: "Bye", color: "Red")
    end

    perform_enqueued_jobs do
      Product.reindex(:search_name, mode: :async)
    end

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false
  end

  def test_relation_queue
    Product.create!(name: "Hi")
    error = assert_raises(Searchkick::Error) do
      Product.reindex(:search_name, mode: :queue)
    end
    assert_equal "Partial reindex not supported with queue option", error.message
  end

  def test_relation_missing_inline
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.searchkick_index.remove(product)

    error = assert_raises(Searchkick::ImportError) do
      Product.reindex(:search_name)
    end
    assert_match "document missing", error.message
  end

  def test_relation_on_missing_ignore_inline
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.searchkick_index.remove(product)

    Product.where(id: product.id).reindex(:search_name, on_missing: :ignore)
  end

  def test_relation_missing_async
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.searchkick_index.remove(product)

    perform_enqueued_jobs do
      error = assert_raises(Searchkick::ImportError) do
        Product.reindex(:search_name, mode: :async)
      end
      assert_match "document missing", error.message
    end
  end

  def test_relation_on_missing_ignore_async
    store [{name: "Hi", color: "Blue"}]

    product = Product.first
    Product.searchkick_index.remove(product)

    perform_enqueued_jobs do
      Product.where(id: product.id).reindex(:search_name, mode: :async, on_missing: :ignore)
    end
  end

  def test_ignore_missing_deprecated
    store [{name: "Hi", color: "Blue"}]
    product = Product.first
    Product.searchkick_index.remove(product)

    assert_warns("ignore_missing is deprecated, use on_missing: :ignore instead") do
      product.reindex(:search_name, ignore_missing: true)
    end
  end

  def test_record_on_missing_raise_explicit
    store [{name: "Hi", color: "Blue"}]
    product = Product.first
    Product.searchkick_index.remove(product)

    error = assert_raises(Searchkick::ImportError) do
      product.reindex(:search_name, on_missing: :raise)
    end
    assert_match "document missing", error.message
  end

  def test_record_on_missing_full_inline
    store [{name: "Hi", color: "Blue"}]
    product = Product.first
    Product.searchkick_index.remove(product)
    Searchkick.callbacks(false) { product.update!(name: "Bye", color: "Red") }

    product.reindex(:search_name, on_missing: :full, refresh: true)

    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "red", ["Bye"], fields: [:color], load: false
  end

  def test_record_on_missing_full_async
    store [{name: "Hi", color: "Blue"}]
    product = Product.first
    Product.searchkick_index.remove(product)
    Searchkick.callbacks(false) { product.update!(name: "Bye", color: "Red") }

    perform_enqueued_jobs do
      product.reindex(:search_name, mode: :async, on_missing: :full)
    end
    Product.searchkick_index.refresh

    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "red", ["Bye"], fields: [:color], load: false
  end

  def test_relation_on_missing_full_inline
    store [{name: "Hi", color: "Blue"}]
    product = Product.first
    Product.searchkick_index.remove(product)
    Searchkick.callbacks(false) { product.update!(name: "Bye", color: "Red") }

    Product.where(id: product.id).reindex(:search_name, on_missing: :full)
    Product.searchkick_index.refresh

    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "red", ["Bye"], fields: [:color], load: false
  end

  def test_relation_on_missing_full_async
    store [{name: "Hi", color: "Blue"}]
    product = Product.first
    Product.searchkick_index.remove(product)
    Searchkick.callbacks(false) { product.update!(name: "Bye", color: "Red") }

    perform_enqueued_jobs do
      Product.where(id: product.id).reindex(:search_name, mode: :async, on_missing: :full)
    end
    Product.searchkick_index.refresh

    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "red", ["Bye"], fields: [:color], load: false
  end

  def test_on_missing_full_mixed_batch
    store [{name: "Present", color: "Blue"}, {name: "Missing", color: "Blue"}]
    present = Product.find_by!(name: "Present")
    missing = Product.find_by!(name: "Missing")

    Product.searchkick_index.remove(missing)
    Searchkick.callbacks(false) do
      present.update!(name: "PresentUpdated", color: "Red")
      missing.update!(name: "MissingUpdated", color: "Red")
    end

    Product.where(id: [present.id, missing.id]).reindex(:search_name, on_missing: :full)
    Product.searchkick_index.refresh

    assert_search "presentupdated", ["PresentUpdated"], fields: [:name], load: false
    assert_search "missingupdated", ["MissingUpdated"], fields: [:name], load: false

    assert_search "blue", ["PresentUpdated"], fields: [:color], load: false

    assert_search "red", ["MissingUpdated"], fields: [:color], load: false
  end

  def test_on_missing_full_mixed_with_other_error
    store [
      {name: "Present", color: "Blue"},
      {name: "Missing", color: "Blue"},
      {name: "Error",   color: "Blue"}
    ]
    present_product = Product.find_by!(name: "Present")
    missing_product = Product.find_by!(name: "Missing")
    error_product     = Product.find_by!(name: "Error")

    Product.searchkick_index.remove(missing_product)

    Searchkick.callbacks(false) do
      present_product.update!(name: "PresentUpdated", color: "Red")
      missing_product.update!(name: "MissingUpdated", color: "Red")
      error_product.update!(name: "ErrorUpdated", color: "Red")
    end

    # ES will reject with mapper_parsing_exception
    Product.class_eval do
      alias_method :__orig_search_name, :search_name
      define_method(:search_name) do
        self.name == "ErrorUpdated" ? {name: {nested: "x"}} : __orig_search_name
      end
    end

    error = assert_raises(Searchkick::ImportError) do
      Product.where(id: [present_product.id, missing_product.id, error_product.id])
        .reindex(:search_name, on_missing: :full)
    end
    
    refute_match "document_missing", error.message
    assert_match(/mapper|parsing|illegal/i, error.message)

    Product.searchkick_index.refresh

    assert_search "missingupdated", ["MissingUpdated"], fields: [:name], load: false
    assert_search "red",            ["MissingUpdated"], fields: [:color], load: false
  ensure
    Product.class_eval do
      alias_method :search_name, :__orig_search_name
      remove_method :__orig_search_name
    end
  end

  def test_on_missing_invalid_value
    product = Product.create!(name: "Hi")
    error = assert_raises(ArgumentError) do
      product.reindex(:search_name, on_missing: :ful)
    end
    assert_match "on_missing", error.message
    assert_match ":raise", error.message
  end

  def test_on_missing_and_ignore_missing_conflict
    product = Product.create!(name: "Hi")
    assert_raises(ArgumentError) do
      product.reindex(:search_name, on_missing: :ignore, ignore_missing: true)
    end
  end

  def test_on_missing_and_ignore_missing_false_conflict
    product = Product.create!(name: "Hi")
    assert_raises(ArgumentError) do
      product.reindex(:search_name, on_missing: :raise, ignore_missing: false)
    end
  end
end
