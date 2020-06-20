require_relative "test_helper"

class RoutingTest < Minitest::Test
  def test_query
    query = Store.search("Dollar Tree", routing: "Dollar Tree", execute: false)
    assert_equal query.params[:routing], "Dollar Tree"
  end

  def test_mappings
    mappings = Store.searchkick_index.index_options[:mappings]
    if Searchkick.server_below?("7.0.0")
      mappings = mappings[:store]
    end
    assert_equal mappings[:_routing], required: true
  end

  def test_correct_node
    store_names ["Dollar Tree"], Store
    assert_search "*", ["Dollar Tree"], {routing: "Dollar Tree"}, Store
  end

  def test_incorrect_node
    store_names ["Dollar Tree"], Store
    assert_search "*", ["Dollar Tree"], {routing: "Boom"}, Store
  end

  def test_async
    with_options({routing: true, callbacks: :async}, Song) do
      store_names ["Dollar Tree"], Song
      Song.destroy_all
    end
  end

  def test_queue
    with_options({routing: true, callbacks: :queue}, Song) do
      store_names ["Dollar Tree"], Song
      Song.destroy_all
      Searchkick::ProcessQueueJob.perform_later(class_name: "Song")
    end
  end
end
