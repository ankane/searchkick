module Searchkick
  class Indexer
    attr_reader :queued_items

    def initialize
      @queued_items = []
    end

    def queue(items, true_refresh: false)
      @queued_items.concat(items)
      perform(true_refresh: true_refresh) unless Searchkick.callbacks_value == :bulk
    end

    def perform(true_refresh: false)
      items = @queued_items
      @queued_items = []
      if items.any?
        response = Searchkick.client.bulk(body: items, refresh: Searchkick.refresh_value || true_refresh)
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
