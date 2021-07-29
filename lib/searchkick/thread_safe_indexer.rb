module Searchkick
  class ThreadSafeIndexer
    class LockTimeoutError < StandardError; end

    DEFAULT_LOCK_TIMEOUT_SECONDS = 1

    RECORD_NOT_FOUND_CLASSES = [
      "ActiveRecord::RecordNotFound",
      "Mongoid::Errors::DocumentNotFound",
      "NoBrainer::Error::DocumentNotFound",
      "Cequel::Record::RecordNotFound"
    ]

    def reindex_stale_record(record, method_name = nil, after_reindex_params: nil)
      unless thread_safe?(record.class)
        reindex_record(record, method_name, after_reindex_params: after_reindex_params)
        return
      end

      # always pass routing in case record is deleted
      # before the record reloading
      if record.respond_to?(:search_routing)
        routing = record.search_routing
      end

      find_and_reindex_record(record.class, record.id, method_name, routing: routing, after_reindex_params: after_reindex_params)
    end

    def find_and_reindex_record(model, id, method_name = nil, routing: nil, after_reindex_params: nil)
      acquire_lock(model, id) do
        record =
          begin
            if model.respond_to?(:unscoped)
              model.unscoped.find(id)
            else
              model.find(id)
            end
          rescue => e
            # check by name rather than rescue directly so we don't need
            # to determine which classes are defined
            raise e unless RECORD_NOT_FOUND_CLASSES.include?(e.class.name)
            nil
          end

        unless record
          record = model.new
          record.id = id
          if routing
            record.define_singleton_method(:search_routing) do
              routing
            end
          end
        end

        reindex_record(record, method_name, after_reindex_params: after_reindex_params)
      end
    end

    private

    def thread_safe?(model)
      ENV['SEARCHKICK_DISABLE_THREAD_SAFE'] != 'true' && model.searchkick_index.options[:thread_safe]
    end

    def acquire_lock(model, id)
      unless thread_safe?(model)
        return yield
      end

      lock_name = "SearchkickReindexing_#{model.name}_#{id}"
      lock_timeout_seconds = ENV['SEARCHKICK_THREAD_SAFE_LOCK_TIMEOUT_SECONDS']&.to_f || DEFAULT_LOCK_TIMEOUT_SECONDS

      lock_aquired = model.with_advisory_lock(lock_name, timeout_seconds: lock_timeout_seconds) do
        yield
        true
      end

      raise LockTimeoutError unless lock_aquired
    end

    def reindex_record(record, method_name, after_reindex_params:)
      index = record.class.searchkick_index

      if record.destroyed? || !record.persisted? || !record.should_index?
        begin
          index.remove(record)
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          # do nothing
        end
      else
        if method_name
          index.update_record(record, method_name)
        else
          index.store(record)
        end
      end

      record.after_reindex(after_reindex_params) if record.respond_to?(:after_reindex)
    end
  end
end
