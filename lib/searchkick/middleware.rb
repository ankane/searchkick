require "faraday/middleware"

module Searchkick
  class Middleware < Faraday::Middleware
    def call(env)
      is_search = env_value(env, :url).path.to_s.end_with?("/_search")

      if env_value(env, :method) == :get && is_search
        r = env_value(env, :request)
        if r.is_a?(Hash)
          r[:timeout] = Searchkick.search_timeout
        else
          r.timeout = Searchkick.search_timeout
        end
      end
      @app.call(env)
    end

    def env_value(env, key)
      env.is_a?(Hash) ? env[key] : env.send(key)
    end
  end
end
