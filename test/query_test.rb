require_relative "test_helper"

class TestQuery < Minitest::Unit::TestCase
  def test_basic
    store_names ["Milk", "Apple"]
    query = Product.search("milk", execute: false)
    query.body[:query] = {match_all: {}}
    assert_equal ["Apple", "Milk"], query.execute.map(&:name).sort
  end

  def test_invalid_query_error
    q = {
      ranged: {
        created_at: { lt: 'now' }
      }
    }

    assert_raises Searchkick::Errors::InvalidQueryError do
      Product.search('*', query: q)
    end
  end

  def test_missing_index_error
    q = Searchkick::Query.new(Product, '*', { index_name: 'missing_index' })
    assert_raises Searchkick::Errors::MissingIndexError do
      q.execute
    end
  end

  def test_deprecated_version_error
    raises_exception = lambda { |s| raise Elasticsearch::Transport::Transport::Error.new(Searchkick::Errors::DeprecatedVersionError::MESSAGES.sample) }
    Searchkick.client.stub :search, raises_exception do
      assert_raises Searchkick::Errors::DeprecatedVersionError do
        Product.search('*')
      end
    end
  end

  def test_search_failed_error
    raises_exception = lambda { |s| raise Elasticsearch::Transport::Transport::Error.new('') }
    Searchkick.client.stub :search, raises_exception do
      assert_raises Searchkick::Errors::SearchFailedError do
        Product.search('*')
      end
    end
  end
end
