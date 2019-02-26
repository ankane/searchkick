require_relative "test_helper"

class IndexerTest < Minitest::Test
  def test_bulk_index_raises_rejection
    error_response = {
      "took" => 15,
      "errors" => true,
      "items" => [
        {
          "index" => {
            "_index" => "foo",
            "_type" => "user",
            "_id" => "3330",
            "_version" => 13,
            "_shards" => {
              "total" => 2,
              "successful" => 1,
              "failed" => 0
            },
            "status" => 200
          }
        },
        {
          "index" => {
            "_index" => "foo",
            "_type" => "user",
            "_id" => "3545",
            "status" => 429,
            "error" => {
              "type" => "es_rejected_execution_exception",
              "reason" => "rejected execution of org.elasticsearch.transport.TransportService$4@14d0f204 on EsThreadPoolExecutor[bulk, queue capacity = 1, org.elasticsearch.common.util.concurrent.EsThreadPoolExecutor@2d0fb6d4[Running, pool size = 1, active threads = 1, queued tasks = 1, completed tasks = 18]]"
            }
          }
        }
      ]
    }

    items = [
      {
        :index => {
          :_index => "foo",
          :_id => 3330,
          :_type => "user",
          :data => {
            "id" => 3330,
          }
        }
      }
    ]

    Searchkick.client.stub :bulk, error_response do
      e = assert_raises Searchkick::ImportError do
        Searchkick::Indexer.new.queue(items)
      end

      assert_equal 1, e.failures.size
    end
  end
end
