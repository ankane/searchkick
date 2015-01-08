module Searchkick
  class ReindexV2Job < ActiveJob::Base
    queue_as :searchkick
    attr_reader :klass, :id

    def perform(klass, id)
      if record and record.should_index?
        index.store record
      else
        begin
          index.remove(model.new(id: id))
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          # do nothing
        end
      end
    end

    private

    def model
      @model ||= klass.constantize
    end

    def record
      @record ||= model.find_by id: id
    end

    def index
      @index ||= model.searchkick_index
    end

  end
end
