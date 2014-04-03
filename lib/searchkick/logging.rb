# based on https://gist.github.com/mnutt/566725

module Searchkick
  class Query
    def execute_with_instrumentation
      event = {
        name: "#{searchkick_klass.name} Search",
        query: params
      }
      ActiveSupport::Notifications.instrument("search.searchkick", event) do
        execute_without_instrumentation
      end
    end

    alias_method_chain :execute, :instrumentation
  end

  class LogSubscriber < ActiveSupport::LogSubscriber
    def self.runtime=(value)
      Thread.current[:searchkick_runtime] = value
    end

    def self.runtime
      Thread.current[:searchkick_runtime] ||= 0
    end

    def self.reset_runtime
      rt, self.runtime = runtime, 0
      rt
    end

    def search(event)
      self.class.runtime += event.duration
      return unless logger.debug?

      payload = event.payload
      name = "#{payload[:name]} (#{event.duration.round(1)}ms)"
      type = payload[:query][:type]

      debug "  #{color(name, YELLOW, true)}  curl http://localhost:9200/#{CGI.escape(payload[:query][:index])}#{type ? "/#{type.map{|t| CGI.escape(t) }.join(",")}" : ""}/_search?pretty -d '#{payload[:query][:body].to_json}'"
    end
  end

  module ControllerRuntime
    extend ActiveSupport::Concern

    protected

    def append_info_to_payload(payload)
      super
      payload[:searchkick_runtime] = Searchkick::LogSubscriber.runtime
    end

    module ClassMethods
      def log_process_action(payload)
        messages, runtime = super, payload[:searchkick_runtime]
        messages << ("Searchkick: %.1fms" % runtime.to_f) if runtime.to_f > 0
        messages
      end
    end
  end
end

Searchkick::LogSubscriber.attach_to :searchkick
ActiveSupport.on_load(:action_controller) do
  include Searchkick::ControllerRuntime
end
