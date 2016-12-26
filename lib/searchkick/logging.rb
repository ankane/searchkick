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

    def import(records)
      if records.any?
        event = {
          name: "#{records.first.searchkick_klass.name} Import",
          count: records.size
        }
        ActiveSupport::Notifications.instrument("request.searchkick", event) do
          super(records)
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
        body: searches.flat_map { |q| [q.params.except(:body).to_json, q.body.to_json] }.map { |v| "#{v}\n" }.join
      }
      ActiveSupport::Notifications.instrument("multi_search.searchkick", event) do
        super
      end
    end
  end

  # https://github.com/rails/rails/blob/master/activerecord/lib/active_record/log_subscriber.rb
  class LogSubscriber < ActiveSupport::LogSubscriber
    def self.runtime=(value)
      Thread.current[:searchkick_runtime] = value
    end

    def self.runtime
      Thread.current[:searchkick_runtime] ||= 0
    end

    def self.reset_runtime
      rt = runtime
      self.runtime = 0
      rt
    end

    def search(event)
      self.class.runtime += event.duration
      return unless logger.debug?

      payload = event.payload
      name = "#{payload[:name]} (#{event.duration.round(1)}ms)"
      type = payload[:query][:type]
      index = payload[:query][:index].is_a?(Array) ? payload[:query][:index].join(",") : payload[:query][:index]

      # no easy way to tell which host the client will use
      host = Searchkick.client.transport.hosts.first
      debug "  #{color(name, YELLOW, true)}  curl #{host[:protocol]}://#{host[:host]}:#{host[:port]}/#{CGI.escape(index)}#{type ? "/#{type.map { |t| CGI.escape(t) }.join(',')}" : ''}/_search?pretty -d '#{payload[:query][:body].to_json}'"
    end

    def request(event)
      self.class.runtime += event.duration
      return unless logger.debug?

      payload = event.payload
      name = "#{payload[:name]} (#{event.duration.round(1)}ms)"

      debug "  #{color(name, YELLOW, true)}  #{payload.except(:name).to_json}"
    end

    def multi_search(event)
      self.class.runtime += event.duration
      return unless logger.debug?

      payload = event.payload
      name = "#{payload[:name]} (#{event.duration.round(1)}ms)"

      # no easy way to tell which host the client will use
      host = Searchkick.client.transport.hosts.first
      debug "  #{color(name, YELLOW, true)}  curl #{host[:protocol]}://#{host[:host]}:#{host[:port]}/_msearch?pretty -d '#{payload[:body]}'"
    end
  end

  # https://github.com/rails/rails/blob/master/activerecord/lib/active_record/railties/controller_runtime.rb
  module ControllerRuntime
    extend ActiveSupport::Concern

    protected

    attr_internal :searchkick_runtime

    def process_action(action, *args)
      # We also need to reset the runtime before each action
      # because of queries in middleware or in cases we are streaming
      # and it won't be cleaned up by the method below.
      Searchkick::LogSubscriber.reset_runtime
      super
    end

    def cleanup_view_runtime
      searchkick_rt_before_render = Searchkick::LogSubscriber.reset_runtime
      runtime = super
      searchkick_rt_after_render = Searchkick::LogSubscriber.reset_runtime
      self.searchkick_runtime = searchkick_rt_before_render + searchkick_rt_after_render
      runtime - searchkick_rt_after_render
    end

    def append_info_to_payload(payload)
      super
      payload[:searchkick_runtime] = (searchkick_runtime || 0) + Searchkick::LogSubscriber.reset_runtime
    end

    module ClassMethods
      def log_process_action(payload)
        messages = super
        runtime = payload[:searchkick_runtime]
        messages << ("Searchkick: %.1fms" % runtime.to_f) if runtime.to_f > 0
        messages
      end
    end
  end
end
Searchkick::Query.send(:prepend, Searchkick::QueryWithInstrumentation)
Searchkick::Index.send(:prepend, Searchkick::IndexWithInstrumentation)
Searchkick::Indexer.send(:prepend, Searchkick::IndexerWithInstrumentation)
Searchkick.singleton_class.send(:prepend, Searchkick::SearchkickWithInstrumentation)
Searchkick::LogSubscriber.attach_to :searchkick
ActiveSupport.on_load(:action_controller) do
  include Searchkick::ControllerRuntime
end
