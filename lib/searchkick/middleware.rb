require "faraday/middleware"

module Searchkick
  class Middleware < Faraday::Middleware
    def call(env)
      if env[:method] == :get && env[:url].path.to_s.end_with?("/_search")
        env[:request][:timeout] = Searchkick.search_timeout
      end
      started_at = Time.now
      r = @app.call(env)
      puts (Time.now - started_at).round(1)
      r
    end
  end
end
