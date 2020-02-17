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
      if items.any?
        bulk_index_options = { body: items }
        bulk_index_options[:refresh] = "wait_for" if Searchkick.refresh_wait_for

        response = Searchkick.client.bulk(bulk_index_options)
        if response["errors"]
          first_with_error = response["items"].map do |item|
            (item["index"] || item["delete"] || item["update"])
          end.find { |item| item["error"] }
          raise Searchkick::ImportError, "#{first_with_error["error"]} on item with id '#{first_with_error["_id"]}'"
        end
      end
    end
  end
end
