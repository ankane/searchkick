module Searchkick
  class Index
    module Records
      def store(record)
        bulk_index([record])
      end

      def remove(record)
        bulk_delete([record])
      end

      def bulk_delete(records)
        Searchkick.queue_items(records.reject { |r| r.id.blank? }.map { |r| {delete: {_index: name, _type: document_type(r), _id: search_id(r)}} })
      end

      def bulk_index(records)
        Searchkick.queue_items(records.map { |r| {index: {_index: name, _type: document_type(r), _id: search_id(r), data: search_data(r)}} })
      end
      alias_method :import, :bulk_index

      def retrieve(record)
        client.get(
          index: name,
          type: document_type(record),
          id: search_id(record)
        )["_source"]
      end

      def reindex_record(record)
        if record.destroyed? || !record.should_index?
          begin
            remove(record)
          rescue Elasticsearch::Transport::Transport::Errors::NotFound
            # do nothing
          end
        else
          store(record)
        end
      end

      def reindex_record_async(record)
        if Searchkick.callbacks_value.nil?
          if defined?(Searchkick::ReindexV2Job)
            Searchkick::ReindexV2Job.perform_later(record.class.name, record.id.to_s)
          else
            Delayed::Job.enqueue Searchkick::ReindexJob.new(record.class.name, record.id.to_s)
          end
        else
          reindex_record(record)
        end
      end

      def similar_record(record, options = {})
        like_text = retrieve(record).to_hash
          .keep_if { |k, _| !options[:fields] || options[:fields].map(&:to_s).include?(k) }
          .values.compact.join(" ")

        # TODO deep merge method
        options[:where] ||= {}
        options[:where][:_id] ||= {}
        options[:where][:_id][:not] = record.id.to_s
        options[:limit] ||= 10
        options[:similar] = true

        # TODO use index class instead of record class
        search_model(record.class, like_text, options)
      end
    end
  end
end
