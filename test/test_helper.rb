require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "logger"
require "active_support/core_ext" if defined?(NoBrainer)
require "active_support/notifications"

ENV["RACK_ENV"] = "test"

$logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDOUT : nil)

Searchkick.client.transport.logger = $logger
Searchkick.search_timeout = 5
Searchkick.index_suffix = ENV["TEST_ENV_NUMBER"] # for parallel tests

# add to elasticsearch-7.0.0/config/
Searchkick.wordnet_path = "wn_s.pl" if ENV["WORDNET"]

puts "Running against Elasticsearch #{Searchkick.server_version}"

if defined?(Redis)
  if defined?(ConnectionPool)
    Searchkick.redis = ConnectionPool.new { Redis.new }
  else
    Searchkick.redis = Redis.new
  end
end

I18n.config.enforce_available_locales = true

if defined?(ActiveJob)
  ActiveJob::Base.logger = $logger
  ActiveJob::Base.queue_adapter = :inline
end

ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT) if ENV["NOTIFICATIONS"]

if defined?(Mongoid)
  require_relative "support/mongoid"
elsif defined?(NoBrainer)
  require_relative "support/nobrainer"
elsif defined?(Cequel)
  require_relative "support/cequel"
else
  require_relative "support/activerecord"
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

class Minitest::Test
  def setup
    Product.destroy_all
    Store.destroy_all
    Animal.destroy_all
    Speaker.destroy_all
  end

  protected

  def store(documents, klass = Product)
    documents.shuffle.each do |document|
      klass.create!(document)
    end
    klass.searchkick_index.refresh
  end

  def store_names(names, klass = Product)
    store names.map { |name| {name: name} }, klass
  end

  # no order
  def assert_search(term, expected, options = {}, klass = Product)
    assert_equal expected.sort, klass.search(term, options).map(&:name).sort
  end

  def assert_order(term, expected, options = {}, klass = Product)
    assert_equal expected, klass.search(term, options).map(&:name)
  end

  def assert_equal_scores(term, options = {}, klass = Product)
    assert_equal 1, klass.search(term, options).hits.map { |a| a["_score"] }.uniq.size
  end

  def assert_first(term, expected, options = {}, klass = Product)
    assert_equal expected, klass.search(term, options).map(&:name).first
  end

  def assert_misspellings(term, expected, misspellings = {}, klass = Product)
    options = {
      fields: [:name, :color],
      misspellings: misspellings
    }
    assert_search(term, expected, options, klass)
  end

  def with_options(klass, options)
    previous_options = klass.searchkick_options.dup
    begin
      klass.searchkick_options.merge!(options)
      klass.reindex
      yield
    ensure
      klass.searchkick_options.clear
      klass.searchkick_options.merge!(previous_options)
    end
  end

  def nobrainer?
    defined?(NoBrainer)
  end

  def cequel?
    defined?(Cequel)
  end
end
