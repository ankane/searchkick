module Searchkick
  class ReindexQueue
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def push(record_id)
      redis.lpush(redis_key, record_id)
    end

    # TODO use reliable queuing
    def reserve(limit: 1000)
      record_ids = Set.new
      while record_ids.size < limit && record_id = redis.rpop(redis_key)
        record_ids << record_id
      end
      record_ids.to_a
    end

    def clear
      redis.del(redis_key)
    end

    def length
      redis.llen(redis_key)
    end

    private

    def redis
      Searchkick.redis
    end

    def redis_key
      "searchkick:reindex_queue:#{name}"
    end
  end
end
