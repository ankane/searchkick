module Searchkick
  module Resque
    class ReindexJob
      @queue = "01_searchkick_reindex_queue"

      def self.perform(klass, id)
        model = klass.constantize
        record = model.find(id) rescue nil # TODO fix lazy coding
        index = model.searchkick_index
        if !record or !record.should_index?
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
end
