module Searchkick
  class ProcessQueueJob < ActiveJob::Base
    queue_as { Searchkick.queue_name }

    def perform(class_name:)
      model = class_name.constantize
      limit = model.searchkick_options[:batch_size] || 1000

      loop do
        record_ids = model.searchkick_index.reindex_queue.reserve(limit: limit)
        if record_ids.any?
          Searchkick::ProcessBatchJob.perform_later(
            class_name: class_name,
            record_ids: record_ids
          )
          # TODO when moving to reliable queuing, mark as complete
        end
        break unless record_ids.size == limit
      end
    end
  end
end
