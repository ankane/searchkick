module Searchkick
  class RecordIndexer
    attr_reader :record, :index

    def initialize(record)
      @record = record
      @index = record.class.searchkick_index
    end

    def reindex(method_name = nil, refresh: false, mode: nil)
      unless [:inline, true, nil, :async, :queue].include?(mode)
        raise ArgumentError, "Invalid value for mode"
      end

      mode ||= Searchkick.callbacks_value || index.options[:callbacks] || true

      case mode
      when :queue
        if method_name
          raise Searchkick::Error, "Partial reindex not supported with queue option"
        end

        index.reindex_queue.push(record.id.to_s)
      when :async
        unless defined?(ActiveJob)
          raise Searchkick::Error, "Active Job not found"
        end

        Searchkick::ReindexV2Job.perform_later(
          record.class.name,
          record.id.to_s,
          method_name ? method_name.to_s : nil
        )
      else # bulk, inline/true/nil
        reindex_record(method_name)

        index.refresh if refresh
      end
    end

    private

    def reindex_record(method_name)
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
    end
  end
end
