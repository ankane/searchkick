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
      record = load_record(model, id)

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

    private

    def load_record(model, id)
      scope = model

      if model.respond_to?(:unscoped)
        scope = scope.unscoped
      end

      if scope.respond_to?(:search_import)
        scope = scope.search_import
      end

      begin
        scope.find(id)
      rescue => e
        # Check by name rather than rescue directly so we don't
        # need to determine which classes are defined.
        unless RECORD_NOT_FOUND_CLASSES.include?(e.class.name)
          raise e
        end
      end
    end
  end
end
