require_relative "test_helper"

class ProcessBatchJobTest < Minitest::Test
  def setup
    skip unless defined?(ActiveJob)
    Product.search_index.reindex_queue.clear
    super
  end

  def test_bulk_index
    product = Searchkick.callbacks(false) { Product.create!(name: "Boom") }
    Product.search_index.refresh
    assert_search "*", []
    Searchkick::ProcessBatchJob.new.perform(class_name: "Product", record_ids: [product.id.to_s])
    Product.search_index.refresh
    assert_search "*", ["Boom"]
  end

  def test_bulk_index_handles_rejection
    product = Searchkick.callbacks(false) { Product.create!(name: "Boom") }

    error_response = {
      "took" => 15,
      "errors" => true,
      "items" => [
        {
          "index" => {
            "_index" => "foo",
            "_type" => "product",
            "_id" => product.id.to_s,
            "status" => 429,
            "error" => {
              "type" => "es_rejected_execution_exception",
              "reason" => "rejected execution of org.elasticsearch.transport.TransportService$4@14d0f204 on EsThreadPoolExecutor[bulk, queue capacity = 1, org.elasticsearch.common.util.concurrent.EsThreadPoolExecutor@2d0fb6d4[Running, pool size = 1, active threads = 1, queued tasks = 1, completed tasks = 18]]"
            }
          }
        }
      ]
    }
    assert_equal 0, Product.search_index.reindex_queue.length
    Searchkick.client.stub :bulk, error_response do
      Searchkick::ProcessBatchJob.new.perform(class_name: "Product", record_ids: [product.id.to_s])
    end
    assert_equal 1, Product.search_index.reindex_queue.length
    id = Product.search_index.reindex_queue.reserve.first
    assert_equal product.id.to_s, id
  end
end
