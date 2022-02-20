module Searchkick
  class ReindexV2Job < ActiveJob::Base
    RECORD_NOT_FOUND_CLASSES = [
      "ActiveRecord::RecordNotFound",
      "Mongoid::Errors::DocumentNotFound"
    ]

    queue_as { Searchkick.queue_name }

    def perform(klass, id, method_name = nil, routing: nil)
      model = klass.constantize
      record =
        begin
          if model.respond_to?(:unscoped)
            model.unscoped.find(id)
          else
            model.find(id)
          end
        rescue => e
          # check by name rather than rescue directly so we don't need
          # to determine which classes are defined
          raise e unless RECORD_NOT_FOUND_CLASSES.include?(e.class.name)
          nil
        end

      # TODO move construct_record logic
      record ||= model.searchkick_index.send(:bulk_record_indexer).send(:construct_record, model, id, routing)

      RecordIndexer.new(record).reindex(method_name, mode: :inline)
    end
  end
end
