module Searchkick
  class ReindexV2Job < ActiveJob::Base
    queue_as { Searchkick.queue_name }

    def perform(klass, id, method_name = nil, routing: nil)
      model = klass.constantize
      # use should_index? to decide whether to index (not default scope)
      # just like saving inline
      # could use Searchkick.scope() in future
      # but keep for now for backwards compatibility
      model = model.unscoped if model.respond_to?(:unscoped)
      items = [{id: id, routing: routing}]
      model.searchkick_index.send(:record_indexer).reindex_items(model, items, method_name: method_name, single: true)
    end
  end
end
