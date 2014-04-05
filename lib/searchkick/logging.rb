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

  # https://github.com/rails/rails/blob/master/activerecord/lib/active_record/log_subscriber.rb
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

      # no easy way to tell which host the client will use
      host = Searchkick.client.transport.hosts.first
      debug "  #{color(name, YELLOW, true)}  curl #{host[:protocol]}://#{host[:host]}:#{host[:port]}/#{CGI.escape(payload[:query][:index])}#{type ? "/#{type.map{|t| CGI.escape(t) }.join(",")}" : ""}/_search?pretty -d '#{payload[:query][:body].to_json}'"
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
