module Searchkick
  class ProcessQueueJob < ActiveJob::Base
    queue_as :searchkick

    def perform(class_name:)
      model = class_name.constantize

      limit = model.searchkick_index.options[:batch_size] || 1000
      record_ids = model.searchkick_index.reindex_queue.reserve(limit: limit)
      if record_ids.any?
        Searchkick::ProcessBatchJob.perform_later(
          class_name: model.name,
          record_ids: record_ids
        )
        # TODO when moving to reliable queuing, mark as complete

        if record_ids.size == limit
          Searchkick::ProcessQueueJob.perform_later(class_name: class_name)
        end
      end
    end
  end
end
