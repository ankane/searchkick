# based on https://gist.github.com/mnutt/566725
require "active_support/core_ext/module/attr_internal"

module Searchkick
  module QueryWithInstrumentation
    def execute_search
      name = searchkick_klass ? "#{searchkick_klass.name} Search" : "Search"
      event = {
        name: name,
        query: params
      }
      ActiveSupport::Notifications.instrument("search.searchkick", event) do
        super
      end
    end
  end

  module IndexWithInstrumentation
    def store(record)
      event = {
        name: "#{record.searchkick_klass.name} Store",
        id: search_id(record)
      }
      if Searchkick.callbacks_value == :bulk
        super
      else
        ActiveSupport::Notifications.instrument("request.searchkick", event) do
          super
        end
      end
    end

    def remove(record)
      name = record && record.searchkick_klass ? "#{record.searchkick_klass.name} Remove" : "Remove"
      event = {
        name: name,
        id: search_id(record)
      }
      if Searchkick.callbacks_value == :bulk
        super
      else
        ActiveSupport::Notifications.instrument("request.searchkick", event) do
          super
        end
      end
    end

    def update_record(record, method_name)
      event = {
        name: "#{record.searchkick_klass.name} Update",
        id: search_id(record)
      }
      if Searchkick.callbacks_value == :bulk
        super
      else
        ActiveSupport::Notifications.instrument("request.searchkick", event) do
          super
        end
      end
    end

    def bulk_index(records)
      if records.any?
        event = {
          name: "#{records.first.searchkick_klass.name} Import",
          count: records.size
        }
        event[:id] = search_id(records.first) if records.size == 1
        if Searchkick.callbacks_value == :bulk
          super
        else
          ActiveSupport::Notifications.instrument("request.searchkick", event) do
            super
          end
        end
      end
    end
    alias_method :import, :bulk_index

    def bulk_update(records, *args)
      if records.any?
        event = {
          name: "#{records.first.searchkick_klass.name} Update",
          count: records.size
        }
        event[:id] = search_id(records.first) if records.size == 1
        if Searchkick.callbacks_value == :bulk
          super
        else
          ActiveSupport::Notifications.instrument("request.searchkick", event) do
            super
          end
        end
      end
    end

    def bulk_delete(records)
      if records.any?
        event = {
          name: "#{records.first.searchkick_klass.name} Delete",
          count: records.size
        }
        event[:id] = search_id(records.first) if records.size == 1
        if Searchkick.callbacks_value == :bulk
          super
        else
          ActiveSupport::Notifications.instrument("request.searchkick", event) do
            super
          end
        end
      end
    end
  end

  module IndexerWithInstrumentation
    def perform
      if Searchkick.callbacks_value == :bulk
        event = {
          name: "Bulk",
          count: queued_items.size
        }
        ActiveSupport::Notifications.instrument("request.searchkick", event) do
          super
        end
      else
        super
      end
    end
  end

  module SearchkickWithInstrumentation
    def multi_search(searches)
      event = {
        name: "Multi Search",
        body: searches.flat_map { |q| [q.params.except(:body).to_json, q.body.to_json] }.map { |v| "#{v}\n" }.join,
      }
      ActiveSupport::Notifications.instrument("multi_search.searchkick", event) do
        super
      end
    end
  end
end

Searchkick::Query.prepend(Searchkick::QueryWithInstrumentation)
Searchkick::Index.prepend(Searchkick::IndexWithInstrumentation)
Searchkick::Indexer.prepend(Searchkick::IndexerWithInstrumentation)
Searchkick.singleton_class.prepend(Searchkick::SearchkickWithInstrumentation)
