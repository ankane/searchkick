module Searchkick
  class RelationIndexer
    attr_reader :index

    def initialize(index)
      @index = index
    end

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

      bulk_record_indexer.import_inline(records, delete_records, method_name: nil)
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

    def import_scope(relation, resume: false, method_name: nil, async: false, full: false, scope: nil, mode: nil)
      if scope
        relation = relation.send(scope)
      elsif relation.respond_to?(:search_import)
        relation = relation.search_import
      end

      mode ||= (async ? :async : :inline)

      if full && async
        full_reindex_async(relation)
      elsif relation.respond_to?(:find_in_batches)
        if resume
          # use total docs instead of max id since there's not a great way
          # to get the max _id without scripting since it's a string

          # TODO use primary key and prefix with table name
          relation = relation.where("id > ?", index.total_docs)
        end

        relation = relation.select("id").except(:includes, :preload) if mode == :async

        relation.find_in_batches batch_size: batch_size do |items|
          import_or_update items, method_name, mode, full
        end
      else
        each_batch(relation) do |items|
          import_or_update items, method_name, mode, full
        end
      end
    end

    def batches_left
      Searchkick.with_redis { |r| r.scard(batches_key) }
    end

    def batch_completed(batch_id)
      Searchkick.with_redis { |r| r.srem(batches_key, batch_id) }
    end

    private

    def import_or_update(records, method_name, mode, full)
      bulk_record_indexer.reindex(
        records,
        mode: mode,
        method_name: method_name,
        full: full
      )
    end

    def full_reindex_async(scope)
      if scope.respond_to?(:primary_key)
        # TODO expire Redis key
        primary_key = scope.primary_key

        scope = scope.select(primary_key).except(:includes, :preload)

        starting_id =
          begin
            scope.minimum(primary_key)
          rescue ActiveRecord::StatementInvalid
            false
          end

        if starting_id.nil?
          # no records, do nothing
        elsif starting_id.is_a?(Numeric)
          max_id = scope.maximum(primary_key)
          batches_count = ((max_id - starting_id + 1) / batch_size.to_f).ceil

          batches_count.times do |i|
            batch_id = i + 1
            min_id = starting_id + (i * batch_size)
            bulk_reindex_job scope, batch_id, min_id: min_id, max_id: min_id + batch_size - 1
          end
        else
          scope.find_in_batches(batch_size: batch_size).each_with_index do |batch, i|
            batch_id = i + 1

            bulk_reindex_job scope, batch_id, record_ids: batch.map { |record| record.id.to_s }
          end
        end
      else
        batch_id = 1
        # TODO remove any eager loading
        scope = scope.only(:_id) if scope.respond_to?(:only)
        each_batch(scope) do |items|
          bulk_reindex_job scope, batch_id, record_ids: items.map { |i| i.id.to_s }
          batch_id += 1
        end
      end
    end

    def each_batch(scope)
      # https://github.com/karmi/tire/blob/master/lib/tire/model/import.rb
      # use cursor for Mongoid
      items = []
      scope.all.each do |item|
        items << item
        if items.length == batch_size
          yield items
          items = []
        end
      end
      yield items if items.any?
    end

    def bulk_reindex_job(scope, batch_id, options)
      Searchkick.with_redis { |r| r.sadd(batches_key, batch_id) }
      Searchkick::BulkReindexJob.perform_later(**{
        class_name: scope.searchkick_options[:class_name],
        index_name: index.name,
        batch_id: batch_id
      }.merge(options))
    end

    def batches_key
      "searchkick:reindex:#{index.name}:batches"
    end

    def batch_size
      @batch_size ||= index.options[:batch_size] || 1000
    end

    def bulk_record_indexer
      @bulk_record_indexer ||= index.send(:bulk_record_indexer)
    end
  end
end
