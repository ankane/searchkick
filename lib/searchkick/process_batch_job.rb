module Searchkick
  class ProcessBatchJob < ActiveJob::Base
    queue_as { Searchkick.queue_name }

    def perform(class_name:, record_ids:, index_name: nil)
      klass = class_name.constantize
      index = klass.searchkick_index(name: index_name)
      # TODO move import_queue logic
      index.send(:bulk_record_indexer).import_queue(klass, record_ids)
    end
  end
end
