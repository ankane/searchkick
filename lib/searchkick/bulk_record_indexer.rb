module Searchkick
  class BulkRecordIndexer
    attr_reader :index

    def initialize(index)
      @index = index
    end

    def reindex(records, mode:, method_name:, full:)
      return if records.empty?

      case mode
      when :async
        Searchkick::BulkReindexJob.perform_later(
          class_name: records.first.class.searchkick_options[:class_name],
          record_ids: records.map(&:id),
          index_name: index.name,
          method_name: method_name ? method_name.to_s : nil
        )
      when :queue
        if method_name
          raise Searchkick::Error, "Partial reindex not supported with queue option"
        end

        index.reindex_queue.push_records(records)
      when true, :inline
        index_records, other_records = records.partition(&:should_index?)
        import_inline(index_records, !full ? other_records : [], method_name: method_name)
      else
        raise ArgumentError, "Invalid value for mode"
      end
    end

    # import in single request with retries
    # TODO make private
    def import_inline(index_records, delete_records, method_name:)
      return if index_records.empty? && delete_records.empty?

      action = method_name ? "Update" : "Import"
      name = (index_records.first || delete_records.first).searchkick_klass.name
      with_retries do
        Searchkick.callbacks(:bulk, message: "#{name} #{action}") do
          if index_records.any?
            if method_name
              index.bulk_update(index_records, method_name)
            else
              index.bulk_index(index_records)
            end
          end

          if delete_records.any?
            index.bulk_delete(delete_records)
          end
        end
      end
    end

    private

    def with_retries
      retries = 0

      begin
        yield
      rescue Faraday::ClientError => e
        if retries < 1
          retries += 1
          retry
        end
        raise e
      end
    end
  end
end
