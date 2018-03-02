module Searchkick
  class RecordIndexer
    attr_reader :record

    def initialize(record)
      @record = record
    end

    def reindex(method_name = nil, refresh: false, mode: nil)
      return unless Searchkick.callbacks?

      unless [true, nil, :async, :queue].include?(mode)
        raise ArgumentError, "Invalid value for mode"
      end

      index = record.class.searchkick_index

      klass_options = index.options

      if mode.nil?
        mode =
          if Searchkick.callbacks_value
            Searchkick.callbacks_value
          else
            klass_options[:callbacks]
          end
      end

      case mode
      when :queue
        if method_name
          raise Searchkick::Error, "Partial reindex not supported with queue option"
        else
          index.reindex_queue.push(record.id.to_s)
        end
      when :async
        if method_name
          # TODO support Mongoid and NoBrainer and non-id primary keys
          Searchkick::BulkReindexJob.perform_later(
            class_name: record.class.name,
            record_ids: [record.id.to_s],
            method_name: method_name ? method_name.to_s : nil
          )
        else
          index.reindex_record_async(record)
        end
      else
        if method_name
          index.update_record(record, method_name)
        else
          index.reindex_record(record)
        end
        index.refresh if refresh
      end
    end
  end
end
