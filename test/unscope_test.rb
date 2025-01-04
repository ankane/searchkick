require_relative "test_helper"

class UnscopeTest < Minitest::Test
  def setup
    @@once ||= Artist.reindex

    Artist.unscoped.destroy_all
  end

  def test_reindex
    create_records

    Artist.reindex
    assert_search "*", ["Test", "Test 2"]
    assert_search "*", ["Test", "Test 2"], {load: false}
  end

  def test_relation_async
    create_records

    perform_enqueued_jobs do
      Artist.unscoped.reindex(mode: :async)
    end

    Artist.searchkick_index.refresh
    assert_search "*", ["Test", "Test 2"]
  end

  def create_records
    store [
      {name: "Test", active: true, should_index: true},
      {name: "Test 2", active: false, should_index: true},
      {name: "Test 3", active: false, should_index: false}
    ], reindex: false
  end

  def default_model
    Artist
  end
end
