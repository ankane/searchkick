require_relative "test_helper"

class IndexTest < Minitest::Test
  def test_clean_indices
    old_index = Searchkick::Index.new("products_test_20130801000000000")
    different_index = Searchkick::Index.new("items_test_20130801000000000")

    old_index.delete if old_index.exists?
    different_index.delete if different_index.exists?

    # create indexes
    old_index.create
    different_index.create

    Product.clean_indices

    assert Product.searchkick_index.exists?
    assert different_index.exists?
    assert !old_index.exists?
  end

  def test_clean_indices_old_format
    old_index = Searchkick::Index.new("products_test_20130801000000")
    old_index.create

    Product.clean_indices

    assert !old_index.exists?
  end

  def test_total_docs
    store_names ["Product A"]
    assert_equal 1, Product.searchkick_index.total_docs
  end

  def test_mapping
    store_names ["Dollar Tree"], Store
    assert_equal [], Store.search(query: {match: {name: "dollar"}}).map(&:name)
    assert_equal ["Dollar Tree"], Store.search(query: {match: {name: "Dollar Tree"}}).map(&:name)
  end

  def test_json
    store_names ["Dollar Tree"], Store
    assert_equal [], Store.search(query: {match: {name: "dollar"}}).map(&:name)
    assert_equal ["Dollar Tree"], Store.search(json: {query: {match: {name: "Dollar Tree"}}}, load: false).map(&:name)
  end

  def test_body
    store_names ["Dollar Tree"], Store
    assert_equal [], Store.search(query: {match: {name: "dollar"}}).map(&:name)
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
    assert_equal ["dollar", "dollartre", "tree"], Product.searchkick_index.tokens("Dollar Tree")
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
    Product.searchkick_index.remove(OpenStruct.new)
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
    assert_search "product", []
  end

  def test_analyzed_only
    # skip for 5.0 since it throws
    # Cannot search on field [alt_description] since it is not indexed.
    skip unless elasticsearch_below50?
    store [{name: "Product A", alt_description: "Hello"}]
    assert_search "*", [], where: {alt_description: "Hello"}
  end

  def test_analyzed_only_large_value
    skip if nobrainer?
    large_value = 10000.times.map { "hello" }.join(" ")
    store [{name: "Product A", alt_description: large_value}]
    assert_search "product", ["Product A"]
  end
end
