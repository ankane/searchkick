require_relative "test_helper"

class SearchTest < Minitest::Test
  def test_search_relation
    error = assert_raises(Searchkick::Error) do
      Product.all.search("*")
    end
    assert_equal "search must be called on model, not relation", error.message
  end

  def test_body
    store_names ["Dollar Tree"], Store
    assert_equal ["Dollar Tree"], Store.search(body: {query: {match: {name: "dollar"}}}, load: false).map(&:name)
  end

  def test_body_incompatible_options
    assert_raises(ArgumentError) do
      Store.search(body: {query: {match: {name: "dollar"}}}, where: {id: 1})
    end
  end

  def test_block
    store_names ["Dollar Tree"]
    products =
      Product.search "boom" do |body|
        body[:query] = {match_all: {}}
      end
    assert_equal ["Dollar Tree"], products.map(&:name)
  end

  def test_missing_records
    store_names ["Product A", "Product B"]
    product = Product.find_by(name: "Product A")
    product.delete
    assert_output nil, /\[searchkick\] WARNING: Records in search index do not exist in database: Product \d+/ do
      result = Product.search("product")
      assert_equal ["Product B"], result.map(&:name)
      assert_equal [product.id.to_s], result.missing_records.map { |v| v[:id] }
      assert_equal [Product], result.missing_records.map { |v| v[:model] }
    end
    assert_empty Product.search("product", load: false).missing_records
  ensure
    Product.reindex
  end

  def test_bad_mapping
    Product.searchkick_index.delete
    store_names ["Product A"]
    error = assert_raises(Searchkick::InvalidQueryError) { Product.search("test").to_a }
    assert_equal "Bad mapping - run Product.reindex", error.message
  ensure
    Product.reindex
  end

  def test_missing_index
    assert_raises(Searchkick::MissingIndexError) { Product.search("test", index_name: "not_found").to_a }
  end

  def test_unsupported_version
    skip if Searchkick.opensearch?

    raises_exception = lambda do |*|
      if defined?(Elastic::Transport)
        raise Elastic::Transport::Transport::Error, "[500] No query registered for [multi_match]"
      else
        raise Elasticsearch::Transport::Transport::Error, "[500] No query registered for [multi_match]"
      end
    end
    Searchkick.client.stub :search, raises_exception do
      assert_raises(Searchkick::UnsupportedVersionError) { Product.search("test").to_a }
    end
  end

  def test_invalid_body
    assert_raises(Searchkick::InvalidQueryError) { Product.search(body: {boom: true}).to_a }
  end
end
