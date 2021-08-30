require_relative "test_helper"

class IndexTest < Minitest::Test
  def setup
    super
    Region.destroy_all
  end

  def test_tokens
    assert_equal ["dollar", "dollartre", "tree"], Product.search_index.tokens("Dollar Tree", analyzer: "searchkick_index")
  end

  def test_tokens_analyzer
    assert_equal ["dollar", "tree"], Product.search_index.tokens("Dollar Tree", analyzer: "searchkick_search2")
  end

  def test_total_docs
    store_names ["Product A"]
    assert_equal 1, Product.search_index.total_docs
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

    Product.search_index.clean_indices

    assert Product.search_index.exists?
    assert different_index.exists?
    assert !old_index.exists?
  end

  def test_clean_indices_old_format
    suffix = Searchkick.index_suffix ? "_#{Searchkick.index_suffix}" : ""
    old_index = Searchkick::Index.new("products_test#{suffix}_20130801000000")
    old_index.create

    Product.search_index.clean_indices

    assert !old_index.exists?
  end

  def test_retain
    Product.reindex
    assert_equal 1, Product.search_index.all_indices.size
    Product.reindex(retain: true)
    assert_equal 2, Product.search_index.all_indices.size
  end

  def test_mappings
    store_names ["Dollar Tree"], Store
    assert_equal ["Dollar Tree"], Store.search(body: {query: {match: {name: "dollar"}}}).map(&:name)
    mapping = Store.search_index.mapping.values.first["mappings"]
    mapping = mapping["store"] if Searchkick.server_below?("7.0.0")
    assert_equal "text", mapping["properties"]["name"]["type"]
  end

  def test_remove_blank_id
    store_names ["Product A"]
    Product.search_index.remove(Product.new)
    assert_search "product", ["Product A"]
  ensure
    Product.reindex
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
    skip if nobrainer?
    large_value = 1000.times.map { "hello" }.join(" ")
    store [{name: "Product A", text: large_value}], Region
    assert_search "product", ["Product A"], {}, Region
    assert_search "hello", ["Product A"], {fields: [:name, :text]}, Region
    assert_search "hello", ["Product A"], {}, Region
    assert_search "*", ["Product A"], {where: {text: large_value}}, Region
  end

  def test_very_large_value
    skip if nobrainer?
    large_value = 10000.times.map { "hello" }.join(" ")
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
