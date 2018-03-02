module Searchkick
  class ReindexV2Job < ActiveJob::Base
    RECORD_NOT_FOUND_CLASSES = [
      "ActiveRecord::RecordNotFound",
      "Mongoid::Errors::DocumentNotFound",
      "NoBrainer::Error::DocumentNotFound",
      "Cequel::Record::RecordNotFound"
    ]

    queue_as { Searchkick.queue_name }

    def perform(klass, id)
      model = klass.constantize
      record =
        begin
          model.unscoped.find(id)
        rescue => e
          # check by name rather than rescue directly so we don't need
          # to determine which classes are defined
          raise e unless RECORD_NOT_FOUND_CLASSES.include?(e.class.name)
          nil
        end

      unless record
        record = model.new
        record.id = id
      end

      RecordIndexer.new(record).reindex(mode: true)
    end
  end
end
