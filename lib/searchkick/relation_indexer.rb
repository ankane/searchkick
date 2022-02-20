module Searchkick
  class RelationIndexer
    attr_reader :index

    def initialize(index)
      @index = index
    end

    def reindex(relation, resume: false, method_name: nil, async: false, full: false, scope: nil, mode: nil)
      mode ||= (async ? :async : :inline)

      # apply scopes
      if scope
        relation = relation.send(scope)
      elsif relation.respond_to?(:search_import)
        relation = relation.search_import
      end

      # remove unneeded loading for async
      if mode == :async
        if relation.respond_to?(:primary_key)
          relation = relation.select(relation.primary_key).except(:includes, :preload)
        elsif relation.respond_to?(:only)
          relation = relation.only(:_id)
        end
      end

      if mode == :async && full
        return full_reindex_async(relation)
      end

      relation = resume_relation(relation) if resume

      reindex_options = {
        mode: mode,
        method_name: method_name,
        full: full
      }
      record_indexer = RecordIndexer.new(index)

      if relation.respond_to?(:find_in_batches)
        relation.find_in_batches(batch_size: batch_size) do |items|
          record_indexer.reindex(items, **reindex_options)
        end
      else
        each_batch(relation, batch_size: batch_size) do |items|
          record_indexer.reindex(items, **reindex_options)
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

    def resume_relation(relation)
      if relation.respond_to?(:primary_key)
        # use total docs instead of max id since there's not a great way
        # to get the max _id without scripting since it's a string
        where = relation.arel_table[relation.primary_key].gt(index.total_docs)
        relation = relation.where(where)
      else
        raise Error, "Resume not supported for Mongoid"
      end
    end

    def full_reindex_async(relation)
      batch_id = 1
      class_name = relation.searchkick_options[:class_name]

      if relation.respond_to?(:primary_key)
        # TODO expire Redis key
        primary_key = relation.primary_key

        starting_id =
          begin
            relation.minimum(primary_key)
          rescue ActiveRecord::StatementInvalid
            false
          end

        if starting_id.nil?
          # no records, do nothing
        elsif starting_id.is_a?(Numeric)
          max_id = relation.maximum(primary_key)
          batches_count = ((max_id - starting_id + 1) / batch_size.to_f).ceil

          batches_count.times do |i|
            min_id = starting_id + (i * batch_size)
            batch_job(class_name, batch_id, min_id: min_id, max_id: min_id + batch_size - 1)
            batch_id += 1
          end
        else
          relation.find_in_batches(batch_size: batch_size) do |batch|
            batch_job(class_name, batch_id, record_ids: batch.map { |record| record.id.to_s })
            batch_id += 1
          end
        end
      else
        each_batch(relation, batch_size: batch_size) do |items|
          batch_job(class_name, batch_id, record_ids: items.map { |i| i.id.to_s })
          batch_id += 1
        end
      end
    end

    def each_batch(relation, batch_size:)
      # https://github.com/karmi/tire/blob/master/lib/tire/model/import.rb
      # use cursor for Mongoid
      items = []
      relation.all.each do |item|
        items << item
        if items.length == batch_size
          yield items
          items = []
        end
      end
      yield items if items.any?
    end

    def batch_job(class_name, batch_id, **options)
      Searchkick.with_redis { |r| r.sadd(batches_key, batch_id) }
      Searchkick::BulkReindexJob.perform_later(
        class_name: class_name,
        index_name: index.name,
        batch_id: batch_id,
        **options
      )
    end

    def batches_key
      "searchkick:reindex:#{index.name}:batches"
    end

    def batch_size
      @batch_size ||= index.options[:batch_size] || 1000
    end
  end
end
