module Searchkick
  class ReindexJob
    attr_reader :klass, :id

    def initialize(klass, id)
      @klass = klass
      @id = id
    end

    def perform
      if record and record.should_index?
        index.store record
      else
        begin
          index.remove(model.new(id: id))
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          # do nothing.
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
