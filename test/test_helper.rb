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

Searchkick.redis =
  if defined?(ConnectionPool)
    ConnectionPool.new { Redis.new(logger: $logger) }
  else
    Redis.new(logger: $logger)
  end

I18n.config.enforce_available_locales = true

ActiveJob::Base.logger = $logger
ActiveJob::Base.queue_adapter = :inline

ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT) if ENV["NOTIFICATIONS"]

if defined?(Mongoid)
  require_relative "support/mongoid"
else
  require_relative "support/activerecord"
end

def mongoid?
  defined?(Mongoid)
end

# models
Dir["#{__dir__}/models/*"].each do |file|
  require file
end

Product.searchkick_index.delete if Product.searchkick_index.exists?
Product.reindex
Product.reindex # run twice for both index paths
Product.create!(name: "Set mapping")

Store.reindex
Animal.reindex
Speaker.reindex
Region.reindex

require_relative "support/helpers"
