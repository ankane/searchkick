module Searchkick
  class ReindexQueue
    attr_reader :name

    def initialize(name)
      @name = name

      raise Error, "Searchkick.redis not set" unless Searchkick.redis
    end

    # supports single and multiple ids
    def push(record_ids)
      Searchkick.with_redis { |r| r.sadd(redis_key, record_ids) }
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
      Searchkick.with_redis { |r| r.spop(redis_key, limit) }
    end

    def clear
      Searchkick.with_redis { |r| r.del(redis_key) }
    end

    def length
      Searchkick.with_redis { |r| r.scard(redis_key) }
    end

    private

    def redis_key
      "searchkick:reindex_queue:#{name}"
    end

    def escape(value)
      value.gsub("|", "||")
    end
  end
end
