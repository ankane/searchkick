module Searchkick
  class ReindexV2Job < ActiveJob::Base
    queue_as { Searchkick.queue_name }

    def perform(klass, id, method_name = nil, routing: nil, after_reindex_params: nil)
      model = klass.constantize
      Searchkick::ThreadSafeIndexer.new.find_and_reindex_record(model, id, method_name, routing: routing, after_reindex_params: after_reindex_params)
    end
  end
end
