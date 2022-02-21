module Searchkick
  class ReindexV2Job < ActiveJob::Base
    queue_as { Searchkick.queue_name }

    def perform(class_name, id, method_name = nil, routing: nil, index_name: nil)
      model = Searchkick.load_model(class_name, allow_child: true)
      index = index_name ? Searchkick::Index.new(index_name, model.searchkick_options) : model.searchkick_index
      # use should_index? to decide whether to index (not default scope)
      # just like saving inline
      # could use Searchkick.scope() in future
      # but keep for now for backwards compatibility
      model = model.unscoped if model.respond_to?(:unscoped)
      items = [{id: id, routing: routing}]
      index.send(:record_indexer).reindex_items(model, items, method_name: method_name, single: true)
    end
  end
end
