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

    # TODO figure out better place for logic
    def import_queue(klass, record_ids)
      # separate routing from id
      routing = Hash[record_ids.map { |r| r.split(/(?<!\|)\|(?!\|)/, 2).map { |v| v.gsub("||", "|") } }]
      record_ids = routing.keys

      scope = Searchkick.load_records(klass, record_ids)
      scope = scope.search_import if scope.respond_to?(:search_import)
      records = scope.select(&:should_index?)

      # determine which records to delete
      delete_ids = record_ids - records.map { |r| r.id.to_s }
      delete_records =
        delete_ids.map do |id|
          construct_record(klass, id, routing[id])
        end

      import_inline(records, delete_records, method_name: nil)
    end

    private

    # import in single request with retries
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

    def construct_record(klass, id, routing)
      record = klass.new
      record.id = id
      if routing
        record.define_singleton_method(:search_routing) do
          routing
        end
      end
      record
    end

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
