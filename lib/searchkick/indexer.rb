module Searchkick
  class Indexer
    attr_reader :queued_items

    def initialize
      reset_queue!
    end

    def queue(items)
      @queued_items.concat(items)
      perform unless Searchkick.callbacks_value == :bulk
    end

    def perform
      items = @queued_items
      reset_queue!
      return if items.none?

      response = Searchkick.client.bulk(body: items)
      raise_bulk_indexing_exception!(response) if response['errors']
    end

    private

    def reset_queue!
      @queued_items = []
    end

    def raise_bulk_indexing_exception!(response)
      item_responses = response["items"].map do |item|
        (item["index"] || item["delete"] || item["update"])
      end

      failures, successes = item_responses.partition { |item| item["error"] }
      first_with_error = failures.first

      e = Searchkick::ImportError.new "#{first_with_error["error"]} on item with id '#{first_with_error["_id"]}'. Succeeded: #{successes.size}, Failed: #{failures.size}"
      e.failures = failures

      raise e
    end
  end
end
