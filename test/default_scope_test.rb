require_relative "test_helper"

class DefaultScopeTest < Minitest::Test
  def setup
    Band.destroy_all
  end

  def test_reindex
    store [
      {name: "Test", active: true},
      {name: "Test 2", active: false}
    ], reindex: false

    Band.reindex
    assert_search "*", ["Test"], {load: false}
  end

  def test_search
    Band.reindex
    Band.search("*") # test works

    error = assert_raises(Searchkick::Error) do
      Band.all.search("*")
    end
    assert_equal "search must be called on model, not relation", error.message
  end

  def default_model
    Band
  end
end
