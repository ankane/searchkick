module Searchkick
  class Indexer
    attr_reader :queued_items

    def initialize(threads: nil)
      @queued_items = []
      @threads = threads

      if @threads
        require "thread/pool"
        @pool = Thread.pool(2)
      end
    end

    def queue(items)
      @queued_items.concat(items)
      perform unless Searchkick.callbacks_value == :bulk
    end

    def perform
      items = @queued_items
      @queued_items = []

      if items.any?
        process_batch do
          puts Thread.current.object_id
          response = Searchkick.client.bulk(body: items)
          if response["errors"]
            first_with_error = response["items"].map do |item|
              (item["index"] || item["delete"] || item["update"])
            end.find { |item| item["error"] }
            raise Searchkick::ImportError, "#{first_with_error["error"]} on item with id '#{first_with_error["_id"]}'"
          end
        end
      end
    end

    def shutdown
      @pool.shutdown if @pool
    end

    private

    def process_batch
      if @pool
        @pool.process { yield }
      else
        yield
      end
    end
  end
end
