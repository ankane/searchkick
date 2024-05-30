require_relative "test_helper"

class IndexTest < Minitest::Test
  def setup
    super
    setup_region
  end

  def test_tokens
    assert_equal ["dollar", "dollartre", "tree"], Product.searchkick_index.tokens("Dollar Tree", analyzer: "searchkick_index")
  end

  def test_tokens_analyzer
    assert_equal ["dollar", "tree"], Product.searchkick_index.tokens("Dollar Tree", analyzer: "searchkick_search2")
  end

  def test_total_docs
    store_names ["Product A"]
    assert_equal 1, Product.searchkick_index.total_docs
  end

  def test_clean_indices
    suffix = Searchkick.index_suffix ? "_#{Searchkick.index_suffix}" : ""
    old_index = Searchkick::Index.new("products_test#{suffix}_20130801000000000")
    different_index = Searchkick::Index.new("items_test#{suffix}_20130801000000000")

    old_index.delete if old_index.exists?
    different_index.delete if different_index.exists?

    # create indexes
    old_index.create
    different_index.create

    Product.searchkick_index.clean_indices

    assert Product.searchkick_index.exists?
    assert different_index.exists?
    assert !old_index.exists?
  end

  def test_clean_indices_old_format
    suffix = Searchkick.index_suffix ? "_#{Searchkick.index_suffix}" : ""
    old_index = Searchkick::Index.new("products_test#{suffix}_20130801000000")
    old_index.create

    Product.searchkick_index.clean_indices

    assert !old_index.exists?
  end

  def test_retain
    Product.reindex
    assert_equal 1, Product.searchkick_index.all_indices.size
    Product.reindex(retain: true)
    assert_equal 2, Product.searchkick_index.all_indices.size
  end

  def test_mappings
    store_names ["Dollar Tree"], Store
    assert_equal ["Dollar Tree"], Store.search(body: {query: {match: {name: "dollar"}}}).map(&:name)
    mapping = Store.searchkick_index.mapping
    assert_kind_of Hash, mapping
    assert_equal "text", mapping.values.first["mappings"]["properties"]["name"]["type"]
  end

  def test_settings
    assert_kind_of Hash, Store.searchkick_index.settings
  end

  def test_remove_blank_id
    store_names ["Product A"]
    Product.searchkick_index.remove(Product.new)
    assert_search "product", ["Product A"]
  ensure
    Product.reindex
  end

  # keep simple for now, but maybe return client response in future
  def test_store_response
    product = Searchkick.callbacks(false) { Product.create!(name: "Product A") }
    assert_nil Product.searchkick_index.store(product)
  end

  # keep simple for now, but maybe return client response in future
  def test_bulk_index_response
    product = Searchkick.callbacks(false) { Product.create!(name: "Product A") }
    assert_nil Product.searchkick_index.bulk_index([product])
  end

  # TODO move

  def test_filterable
    store [{name: "Product A", alt_description: "Hello"}]
    error = assert_raises(Searchkick::InvalidQueryError) do
      assert_search "*", [], where: {alt_description: "Hello"}
    end
    assert_match "Cannot search on field [alt_description] since it is not indexed", error.message
  end

  def test_filterable_non_string
    store [{name: "Product A", store_id: 1}]
    assert_search "*", ["Product A"], where: {store_id: 1}
  end

  def test_large_value
    large_value = 1000.times.map { "hello" }.join(" ")
    store [{name: "Product A", text: large_value}], Region
    assert_search "product", ["Product A"], {}, Region
    assert_search "hello", ["Product A"], {fields: [:name, :text]}, Region
    assert_search "hello", ["Product A"], {}, Region
    assert_search "*", ["Product A"], {where: {text: large_value}}, Region
  end

  def test_very_large_value
    # terms must be < 32 KB with Elasticsearch 8.10.3+
    # https://github.com/elastic/elasticsearch/pull/99818
    large_value = 5400.times.map { "hello" }.join(" ")
    store [{name: "Product A", text: large_value}], Region
    assert_search "product", ["Product A"], {}, Region
    assert_search "hello", ["Product A"], {fields: [:name, :text]}, Region
    assert_search "hello", ["Product A"], {}, Region
    # keyword not indexed
    assert_search "*", [], {where: {text: large_value}}, Region
  end

  def test_bulk_import_raises_error
    valid_dog = Product.create(name: "2016-01-02")
    invalid_dog = Product.create(name: "Ol' One-Leg")
    mapping = {
      properties: {
        name: {type: "date"}
      }
    }
    index = Searchkick::Index.new "dogs", mappings: mapping, _type: "dog"
    index.delete if index.exists?
    index.create_index
    index.store valid_dog
    assert_raises(Searchkick::ImportError) do
      index.bulk_index [valid_dog, invalid_dog]
    end
  end
end
