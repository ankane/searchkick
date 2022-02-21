module Searchkick
  class ProcessBatchJob < ActiveJob::Base
    queue_as { Searchkick.queue_name }

    def perform(class_name:, record_ids:, index_name: nil)
      klass = class_name.constantize
      index = klass.searchkick_index(name: index_name)

      items =
        record_ids.map do |r|
          parts = r.split(/(?<!\|)\|(?!\|)/, 2)
            .map { |v| v.gsub("||", "|") }
          {id: parts[0], routing: parts[1]}
        end

      klass = Searchkick.scope(klass)
      index.send(:record_indexer).reindex_items(klass, items, method_name: nil)
    end
  end
end
