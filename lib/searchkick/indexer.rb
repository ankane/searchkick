# thread-local (technically fiber-local) indexer
# used to aggregate bulk callbacks across models
module Searchkick
  class Indexer
    attr_reader :queued_items

    def initialize
      @queued_items = []
    end

    def queue(items)
      @queued_items.concat(items)
      perform unless Searchkick.callbacks_value == :bulk
    end

    def perform
      items = @queued_items
      @queued_items = []

      return if items.empty?

      response = Searchkick.client.bulk(body: items)
      if response["errors"]
        # note: delete does not set error when item not found
        first_with_error = response["items"].map do |item|
          (item["index"] || item["delete"] || item["update"])
        end.find.with_index { |item, i| item["error"] && !allow_missing?(items[i], item["error"]) }
        if first_with_error
          raise ImportError, "#{first_with_error["error"]} on item with id '#{first_with_error["_id"]}'"
        end
      end

      # maybe return response in future
      nil
    end

    private

    def allow_missing?(item, error)
      error["type"] == "document_missing_exception" && item.instance_variable_defined?(:@allow_missing)
    end
  end
end
