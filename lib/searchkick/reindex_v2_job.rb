module Searchkick
  class ReindexV2Job < ActiveJob::Base
    RECORD_NOT_FOUND_CLASSES = [
      "ActiveRecord::RecordNotFound",
      "Mongoid::Errors::DocumentNotFound",
      "NoBrainer::Error::DocumentNotFound"
    ]

    queue_as :searchkick

    def perform(klass, id)
      model = klass.constantize
      record =
        begin
          model.find(id)
        rescue => e
          # check by name rather than rescue directly so we don't need
          # to determine which classes are defined
          raise e unless RECORD_NOT_FOUND_CLASSES.include?(e.class.name)
          nil
        end

      unless record
        record ||= model.new
        record.id = id
      end

      model.searchkick_index.reindex_record(record)
    end
  end
end
