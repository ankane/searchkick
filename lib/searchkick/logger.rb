require "tire/rails/logger"
require "tire/rails/logger/log_subscriber"

class Tire::Rails::LogSubscriber

  # better output format
  def search(event)
    self.class.runtime += event.duration
    return unless logger.debug?

    payload = event.payload

    name    = "%s (%.1fms)" % [payload[:name], event.duration]
    query   = payload[:search].to_s

    debug "  #{color(name, YELLOW, true)}  #{query}"
  end

end
