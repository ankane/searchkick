require "backburner"
require "searchkick/backburner/reindex_job"

module Searchkick::Backburner
  class Backend
    def enqueue(klass, id)
      ::Backburner::Worker.enqueue(reindex_job, [klass, id])
    end

    private

    def reindex_job
      Searchkick.reindex_job || ::Searchkick::Backburner::ReindexJob
    end
  end
end
