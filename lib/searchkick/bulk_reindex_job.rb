module Searchkick
  class BulkReindexJob < ActiveJob::Base
    queue_as { Searchkick.queue_name }

    # TODO remove min_id and max_id in Searchkick 6
    def perform(class_name:, record_ids: nil, index_name: nil, method_name: nil, batch_id: nil, min_id: nil, max_id: nil)
      klass = class_name.constantize
      index = index_name ? Searchkick::Index.new(index_name, klass.searchkick_options) : klass.searchkick_index

      # legacy
      record_ids ||= min_id..max_id

      klass = Searchkick.scope(klass)
      relation = Searchkick.load_records(klass, record_ids)
      relation = relation.search_import if relation.respond_to?(:search_import)

      # TODO expose functionality on index
      index.send(:record_indexer).reindex(relation, mode: :inline, method_name: method_name, full: false)
      index.send(:relation_indexer).batch_completed(batch_id) if batch_id
    end
  end
end
