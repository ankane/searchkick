module Searchkick
  class ReindexV2Job < ActiveJob::Base
    queue_as { Searchkick.queue_name }

    def perform(klass, id, method_name = nil, routing: nil)
      model = klass.constantize
      # may not be needed if calling search_import later
      model = model.unscoped if model.respond_to?(:unscoped)
      items = [{id: id, routing: routing}]
      # TODO improve notification
      model.searchkick_index.send(:bulk_record_indexer).reindex_items(model, items, method_name: method_name)
    end
  end
end
