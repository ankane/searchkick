require_relative "test_helper"

class IndexTest < Minitest::Test
  def setup
    super
    Region.destroy_all
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

  def test_total_docs
    store_names ["Product A"]
    assert_equal 1, Product.searchkick_index.total_docs
  end

  def test_mapping
    store_names ["Dollar Tree"], Store
    assert_equal [], Store.search(body: {query: {match: {name: "dollar"}}}).map(&:name)
    assert_equal ["Dollar Tree"], Store.search(body: {query: {match: {name: "Dollar Tree"}}}).map(&:name)
  end

  def test_body
    store_names ["Dollar Tree"], Store
    assert_equal [], Store.search(body: {query: {match: {name: "dollar"}}}).map(&:name)
    assert_equal ["Dollar Tree"], Store.search(body: {query: {match: {name: "Dollar Tree"}}}, load: false).map(&:name)
  end

  def test_block
    store_names ["Dollar Tree"]
    products =
      Product.search "boom" do |body|
        body[:query] = {match_all: {}}
      end
    assert_equal ["Dollar Tree"], products.map(&:name)
  end

  def test_tokens
    assert_equal ["dollar", "dollartre", "tree"], Product.searchkick_index.tokens("Dollar Tree", analyzer: "searchkick_index")
  end

  def test_tokens_analyzer
    assert_equal ["dollar", "tree"], Product.searchkick_index.tokens("Dollar Tree", analyzer: "searchkick_search2")
  end

  def test_record_not_found
    store_names ["Product A", "Product B"]
    Product.where(name: "Product A").delete_all
    assert_search "product", ["Product B"]
  ensure
    Product.reindex
  end

  def test_bad_mapping
    Product.searchkick_index.delete
    store_names ["Product A"]
    assert_raises(Searchkick::InvalidQueryError) { Product.search "test" }
  ensure
    Product.reindex
  end

  def test_remove_blank_id
    store_names ["Product A"]
    Product.searchkick_index.remove(Product.new)
    assert_search "product", ["Product A"]
  ensure
    Product.reindex
  end

  def test_missing_index
    assert_raises(Searchkick::MissingIndexError) { Product.search("test", index_name: "not_found") }
  end

  def test_unsupported_version
    raises_exception = ->(_) { raise Elasticsearch::Transport::Transport::Error, "[500] No query registered for [multi_match]" }
    Searchkick.client.stub :search, raises_exception do
      assert_raises(Searchkick::UnsupportedVersionError) { Product.search("test") }
    end
  end

  def test_invalid_body
    assert_raises(Searchkick::InvalidQueryError) { Product.search(body: {boom: true}) }
  end

  def test_transaction
    skip unless defined?(ActiveRecord)
    Product.transaction do
      store_names ["Product A"]
      raise ActiveRecord::Rollback
    end
    assert_search "*", []
  end

  def test_filterable
    # skip for 5.0 since it throws
    # Cannot search on field [alt_description] since it is not indexed.
    skip unless elasticsearch_below50?
    store [{name: "Product A", alt_description: "Hello"}]
    assert_search "*", [], where: {alt_description: "Hello"}
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
  end

  def test_very_large_value
    skip if nobrainer? || elasticsearch_below22?
    large_value = 10000.times.map { "hello" }.join(" ")
    store [{name: "Product A", text: large_value}], Region
    assert_search "product", ["Product A"], {}, Region
    assert_search "hello", ["Product A"], {fields: [:name, :text]}, Region
    # values that exceed ignore_above are not included in _all field :(
    # assert_search "hello", ["Product A"], {}, Region
  end
end
