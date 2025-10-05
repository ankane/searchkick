module Searchkick
  class ReindexQueue
    attr_reader :name

    def initialize(name)
      @name = name

      raise Error, "Searchkick.redis not set" unless Searchkick.redis
    end

    # supports single and multiple ids
    def push(record_ids)
      Searchkick.with_redis { |r| r.call("LPUSH", redis_key, record_ids) }
    end

    def push_records(records)
      record_ids =
        records.map do |record|
          # always pass routing in case record is deleted
          # before the queue job runs
          if record.respond_to?(:search_routing)
            routing = record.search_routing
          end

          # escape pipe with double pipe
          value = escape(record.id.to_s)
          value = "#{value}|#{escape(routing)}" if routing
          value
        end

      push(record_ids)
    end

    # TODO use reliable queuing
    def reserve(limit: 1000)
      Searchkick.with_redis { |r| r.call("RPOP", redis_key, limit) }.to_a
    end

    def clear
      Searchkick.with_redis { |r| r.call("DEL", redis_key) }
    end

    def length
      Searchkick.with_redis { |r| r.call("LLEN", redis_key) }
    end

    private

    def redis_key
      "searchkick:reindex_queue:#{name}"
    end

    def escape(value)
      value.to_s.gsub("|", "||")
    end
  end
end
