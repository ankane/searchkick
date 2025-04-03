require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_support/notifications"

ENV["RACK_ENV"] = "test"

# for reloadable synonyms
if ENV["CI"]
  ENV["ES_PATH"] ||= File.join(ENV["HOME"], Searchkick.opensearch? ? "opensearch" : "elasticsearch", Searchkick.server_version)
end

$logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDOUT : nil)

if ENV["LOG_TRANSPORT"]
  transport_logger = ActiveSupport::Logger.new(STDOUT)
  if Searchkick.client.transport.respond_to?(:transport)
    Searchkick.client.transport.transport.logger = transport_logger
  else
    Searchkick.client.transport.logger = transport_logger
  end
end
Searchkick.search_timeout = 5
Searchkick.index_suffix = ENV["TEST_ENV_NUMBER"] # for parallel tests

puts "Running against #{Searchkick.opensearch? ? "OpenSearch" : "Elasticsearch"} #{Searchkick.server_version}"

I18n.config.enforce_available_locales = true

ActiveJob::Base.logger = $logger
ActiveJob::Base.queue_adapter = :test

ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT) if ENV["VERBOSE"]

if defined?(Mongoid)
  require_relative "support/mongoid"
else
  require_relative "support/activerecord"
end

require_relative "support/redis"

# models
Dir["#{__dir__}/models/*"].each do |file|
  require file
end

require_relative "support/helpers"
