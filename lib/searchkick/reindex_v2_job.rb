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
          model.find(id)
        rescue => e
          # check by name rather than rescue directly so we don't need
          # to determine which classes are defined
          raise e unless RECORD_NOT_FOUND_CLASSES.include?(e.class.name)
          nil
        end

      index = model.searchkick_index
      if !record || !record.should_index?
        # hacky
        record ||= model.new
        record.id = id
        begin
          index.remove record
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          # do nothing
        end
      else
        index.store record
      end
    end
  end
end
