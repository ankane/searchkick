require "searchkick/delayed_job/reindex_job"

module Searchkick::DelayedJob
  class Backend
    def enqueue(klass, id)
      Delayed::Job.enqueue reindex_job.new(klass, id)
    end

    private

    def reindex_job
      Searchkick.reindex_job || ::Searchkick::DelayedJob::ReindexJob
    end
  end
end
