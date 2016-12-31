module Searchkick
  class BulkReindexJob < ActiveJob::Base
    queue_as :searchkick

    def perform(klass, ids, method_name, index_name, index_options)
      index = Searchkick::Index.new(index_name, index_options)
      index.import_scope(klass.constantize.where(id: ids), method_name: method_name)
    end
  end
end
