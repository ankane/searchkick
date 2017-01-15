module Searchkick
  class ProcessBatchJob < ActiveJob::Base
    queue_as :searchkick

    def perform(class_name:, record_ids:)
      # job deprecated
      Searchkick::BulkReindexJob.perform_now(
        class_name: class_name,
        record_ids: record_ids,
        delete: true
      )
    end
  end
end
