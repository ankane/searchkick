module Searchkick
  class ReindexV2Job < ActiveJob::Base
    queue_as :searchkick

    attr_accessor :key

    def reindex_mutex
      @@reindex_mutex ||= Mutex.new
    end

    def reindexes
      @@reindexes ||= Hash.new
    end

    def reindex_add
      reindex_mutex.synchronize do
        if reindexes[key].nil?
          reindexes[key] = { count: 1, mutex: Mutex.new }
        else
          reindexes[key][:count] += 1
        end
      end
    end

    def reindex_remove
      reindex_mutex.synchronize do
        reindexes[key][:count] -= 1
        reindexes.delete key if reindexes[key][:count].zero?
      end
    end

    def reindex_synchronize
      reindexes[key][:mutex].synchronize do
        yield
      end
    end

    def perform(klass, id)
      self.key = "#{klass}::#{id}"
      reindex_add
      reindex_synchronize { reindex_model klass, id }
      reindex_remove
    end

    def reindex_model(klass, id)
      model = klass.constantize
      record = model.find(id) rescue nil # TODO fix lazy coding
      index = model.searchkick_index
      if !record || !record.should_index?
        # hacky
        record ||= model.new
        record.id = id
        begin
          index.remove record
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          # do nothing
        end
      else
        index.store record
      end
    end
  end
end
