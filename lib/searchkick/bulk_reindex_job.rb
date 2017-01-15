module Searchkick
  class BulkReindexJob < ActiveJob::Base
    queue_as :searchkick

    def perform(class_name:, record_ids: nil, index_name: nil, method_name: nil, batch_id: nil, min_id: nil, max_id: nil)
      klass = class_name.constantize
      index = index_name ? Searchkick::Index.new(index_name) : klass.searchkick_index
      record_ids ||= min_id..max_id
      index.import_scope(
        Searchkick.load_records(klass, record_ids),
        method_name: method_name,
        batch: true,
        batch_id: batch_id
      )
    end
  end
end
