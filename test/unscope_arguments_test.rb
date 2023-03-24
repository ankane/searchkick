require_relative "test_helper"

class UnscopeTest < Minitest::Test
  def setup
    @@once ||= Album.reindex

    Album.unscoped.destroy_all
  end

  def test_reindex
    create_records

    Album.reindex
    assert_search "*", ["Test", "Test 2", "Test 3"]
    assert_search "*", ["Test", "Test 2", "Test 3"], {load: false}
  end

  def test_relation_async
    create_records

    perform_enqueued_jobs do
      Album.unscoped.reindex(mode: :async)
    end

    Album.search_index.refresh
    assert_search "*", ["Test", "Test 2", "Test 3"]
  end

  def create_records
    store [
      {name: "Test", active: true},
      {name: "Test 2", active: false},
      {name: "Test 3", active: false, sold: false},
    ], reindex: false
  end

  def default_model
    Album
  end
end
