module Searchkick
  class ReindexV2Job < ActiveJob::Base
    RECORD_NOT_FOUND_CLASSES = [
      "ActiveRecord::RecordNotFound",
      "Mongoid::Errors::DocumentNotFound",
      "NoBrainer::Error::DocumentNotFound",
      "Cequel::Record::RecordNotFound"
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

      unless record
        record = model.new
        record.id = id
        if routing
          record.define_singleton_method(:search_routing) do
            routing
          end
        end
      end

      RecordIndexer.new(record).reindex(method_name, mode: :inline)
    end
  end
end
