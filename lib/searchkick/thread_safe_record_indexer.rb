module Searchkick
  class ThreadSafeRecordIndexer
    attr_reader :index

    def initialize(index)
      @index = index
    end

    def reindex_stale_records(index_records, delete_records, method_name:, single:, after_reindex_params: nil)
      return if index_records.empty? && delete_records.empty?

      record = index_records.first || delete_records.first

      unless thread_safe?(record.class)
        # This is legacy behavior, just reindex in-memory state of record whatever is there
        thread_unsafe_record_indexer.import_inline(index_records, delete_records, method_name: method_name, single: single, after_reindex_params: after_reindex_params)
        return
      end

      items = (index_records + delete_records).map { |record|
        # always pass routing in case record is deleted
        # before the record reloading
        {id: record.id, routing: record.try(:routing)}
      }

      # Ignore in-memory state but fetch the actual state from DB
      reindex_items(record.class, items, method_name: method_name, single: single, after_reindex_params: after_reindex_params)
    end


    def reindex_items(klass, items, method_name:, single: false, after_reindex_params: nil)
      records, delete_records, records_data, delete_records_data = if thread_safe?(klass)
        fetch_items(klass, items, method_name)
      else
        thread_unsafe_record_indexer.fetch_items(klass, items)
      end

      # Run versioned ES reindexing out from the locked block, no needs to lock it
      thread_unsafe_record_indexer.import_inline(
        records,
        delete_records,
        method_name: method_name,
        single: single,
        records_data: records_data,
        delete_records_data: delete_records_data,
        after_reindex_params: after_reindex_params
      )
    end

    def thread_safe?(klass)
      ENV['SEARCHKICK_THREAD_SAFE_DISABLED'] != 'true' && klass.searchkick_index.options[:thread_safe]
    end

    private

    def thread_unsafe_record_indexer
      @thread_unsafe_record_indexer ||= RecordIndexer.new(index)
    end

    def fetch_items(klass, items, method_name)
      ids = items.map { |r| r[:id] }

      acquire_locks!(klass, ids) do |versions|
        records, delete_records = thread_unsafe_record_indexer.fetch_items(klass, items)
        # Build index data inside the locked block in order to apply versioning
        # over involded associations as well
        [records, delete_records] + build_record_data(records, delete_records, method_name, external_versions: versions)
      end
    end

    def acquire_locks!(model, ids, &block)
      ids = Array.wrap(ids).compact.uniq.sort
      return yield({}) if !thread_safe?(model) || ids.empty?

      Searchkick::IndexVersion.bump_versions(model, ids, &block)
    end

    def build_record_data(records, delete_records, method_name, external_versions: nil)
      external_versions ||= {}

      records_data = records.map { |record|
        record_data_builder = RecordData.new(index, record, external_version: external_versions[record.id])

        if method_name
          record_data_builder.update_data(method_name)
        else
          record_data_builder.index_data
        end
      }

      delete_records_data = delete_records.map { |record|
        RecordData.new(index, record, external_version: external_versions[record.id]).delete_data
      }

      [records_data, delete_records_data]
    end
  end
end
