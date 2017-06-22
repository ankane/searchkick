module Searchkick
  class ProcessBatchJob < ActiveJob::Base
    queue_as :searchkick

    def perform(class_name:, record_ids:)
      klass = class_name.constantize
      scope = Searchkick.load_records(klass, record_ids)
      scope = scope.search_import if scope.respond_to?(:search_import)
      records = scope.select(&:should_index?)

      # determine which records to delete
      delete_ids = record_ids - records.map { |r| r.id.to_s }
      delete_records = delete_ids.map { |id| m = klass.new; m.id = id; m }

      # bulk reindex
      index = klass.searchkick_index
      Searchkick.callbacks(:bulk) do
        index.bulk_index(records) if records.any?
        index.bulk_delete(delete_records) if delete_records.any?
      end
    end
  end
end
