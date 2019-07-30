module Searchkick
  class ProcessQueueJob < ActiveJob::Base
    queue_as { Searchkick.queue_name }

    def perform(class_name:, index_name: nil, inline: false)
      model = class_name.constantize
      limit = model.searchkick_index.options[:batch_size] || 1000

      loop do
        record_ids = model.searchkick_index(name: index_name).reindex_queue.reserve(limit: limit)
        if record_ids.any?
          perform_method = inline ? :perform_now : :perform_later
          Searchkick::ProcessBatchJob.send(
            perform_method,
            class_name: class_name,
            record_ids: record_ids,
            index_name: index_name
          )
          # TODO when moving to reliable queuing, mark as complete
        end
        break unless record_ids.size == limit
      end
    end
  end
end
