module Searchkick
  class ThreadSafeIndexer
    RECORD_NOT_FOUND_CLASSES = [
      "ActiveRecord::RecordNotFound",
      "Mongoid::Errors::DocumentNotFound",
      "NoBrainer::Error::DocumentNotFound",
      "Cequel::Record::RecordNotFound"
    ]

    def reindex_stale_record(record, method_name = nil, after_reindex_params: nil)
      unless thread_safe?(record.class)
        # This is legacy behavior, just reindex in-memory state of record whatever is there
        thread_unsafe_reindex_record(record, method_name, after_reindex_params: after_reindex_params)
        return
      end

      # always pass routing in case record is deleted
      # before the record reloading
      if record.respond_to?(:search_routing)
        routing = record.search_routing
      end

      # Ignore in-memory state but fetch the actual state from DB
      find_and_reindex_record(record.class, record.id, method_name, routing: routing, after_reindex_params: after_reindex_params)
    end

    def find_and_reindex_record(model, id, method_name = nil, routing: nil, after_reindex_params: nil)
      unless thread_safe?(model)
        record = thread_unsafe_find_record(model, id, routing: routing)
        thread_unsafe_reindex_record(record, method_name, after_reindex_params: after_reindex_params)
        return
      end

      record, record_data = thread_safe_find_record(model, id, method_name, routing: routing)

      begin
        # Run versioned ES reindexing out from the locked block, no needs to lock it
        queue_record_data(record, record_data, after_reindex_params: after_reindex_params)
      rescue Searchkick::ImportError => e
        # Just ignore versioning error
        raise unless e.message.include?('version_conflict_engine_exception')
      end
    end

    def find_in_batches(origin_relation, async:, full:, batch_size:)
      thread_safe_mode = !async && !full && thread_safe?(origin_relation)

      batching_relation = origin_relation
      batching_relation = batching_relation.select("id").except(:includes, :preload) if async || thread_safe_mode

      batching_relation.find_in_batches batch_size: batch_size do |items|
        unless thread_safe_mode
          yield items
          next
        end

        ids = items.map(&:id)
        acquire_locks!(origin_relation.klass, ids) do |versions|
          yield origin_relation.where(id: ids).to_a
        end
      end
    end

    private

    def thread_safe?(model)
      ENV['SEARCHKICK_THREAD_SAFE_DISABLED'] != 'true' && model.searchkick_index.options[:thread_safe]
    end

    def acquire_locks!(model, ids)
      ids = Array.wrap(ids).compact.uniq.sort
      return yield({}) if !thread_safe?(model) || ids.empty?

      Searchkick::IndexVersion.bump_versions(model, ids) do |versions|
        yield(versions)
      end
    end

    def build_record_data(record, method_name, external_version: nil)
      index = record.class.searchkick_index
      record_data_builder = RecordData.new(index, record, external_version: external_version)

      if record.destroyed? || !record.persisted? || !record.should_index?
        record_data_builder.delete_data
      elsif method_name
        record_data_builder.update_data(method_name)
      else
        record_data_builder.index_data
      end
    end

    def queue_record_data(record, record_data, after_reindex_params:)
      Searchkick.indexer.queue([record_data])
      record.after_reindex(after_reindex_params) if record.respond_to?(:after_reindex)
    end

    def thread_unsafe_reindex_record(record, method_name, after_reindex_params:)
      record_data = build_record_data(record, method_name)
      queue_record_data(record, record_data, after_reindex_params: after_reindex_params)
    end

    def thread_unsafe_find_record(model, id, routing:)
      record = begin
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

      record
    end

    def thread_safe_find_record(model, id, method_name, routing:)
      acquire_locks!(model, id) do |versions|
        record = thread_unsafe_find_record(model, id, routing: routing)
        # Build index data inside the locked block in order to apply versioning
        # over involded associations as well
        record_data = build_record_data(record, method_name, external_version: versions[id])

        [record, record_data]
      end
    end
  end
end
