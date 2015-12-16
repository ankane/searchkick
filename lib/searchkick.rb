require "active_model"
require "elasticsearch"
require "hashie"
require "searchkick/version"
require "searchkick/index"
require "searchkick/results"
require "searchkick/query"
require "searchkick/reindex_job"
require "searchkick/model"
require "searchkick/tasks"
require "searchkick/logging" if defined?(Rails)

# background jobs
begin
  require "active_job"
rescue LoadError
  # do nothing
end
require "searchkick/reindex_v2_job" if defined?(ActiveJob)

module Searchkick
  class Error < StandardError; end
  class MissingIndexError < Error; end
  class UnsupportedVersionError < Error; end
  class InvalidQueryError < Elasticsearch::Transport::Transport::Errors::BadRequest; end
  class DangerousOperation < Error; end
  class ImportError < Error; end

  class << self
    attr_accessor :search_method_name
    attr_accessor :wordnet_path
    attr_accessor :timeout
    attr_accessor :models
    attr_writer :env
  end
  self.search_method_name = :search
  self.wordnet_path = "/var/lib/wn_s.pl"
  self.timeout = 10
  self.models = []

  def self.client
    @client ||=
      Elasticsearch::Client.new(
        url: ENV["ELASTICSEARCH_URL"],
        transport_options: {request: {timeout: timeout}}
      )
  end

  class << self
    attr_writer :client
  end

  def self.server_version
    @server_version ||= client.info["version"]["number"]
  end

  def self.enable_callbacks
    self.callbacks_value = nil
  end

  def self.disable_callbacks
    self.callbacks_value = false
  end

  def self.callbacks?
    Thread.current[:searchkick_callbacks_enabled].nil? || Thread.current[:searchkick_callbacks_enabled]
  end

  def self.callbacks(value)
    if block_given?
      previous_value = callbacks_value
      begin
        self.callbacks_value = value
        yield
        perform_bulk if callbacks_value == :bulk
      ensure
        self.callbacks_value = previous_value
      end
    else
      self.callbacks_value = value
    end
  end

  def self.queue_items(items)
    queued_items.concat(items)
    perform_bulk unless callbacks_value == :bulk
  end

  def self.perform_bulk
    items = queued_items
    clear_queued_items
    perform_items(items)
  end

  def self.perform_items(items)
    if items.any?
      response = client.bulk(body: items)
      if response["errors"]
        first_item = response["items"].first
        raise Searchkick::ImportError, (first_item["index"] || first_item["delete"])["error"]
      end
    end
  end

  def self.queued_items
    Thread.current[:searchkick_queued_items] ||= []
  end

  def self.clear_queued_items
    Thread.current[:searchkick_queued_items] = []
  end

  def self.callbacks_value
    Thread.current[:searchkick_callbacks_enabled]
  end

  def self.callbacks_value=(value)
    Thread.current[:searchkick_callbacks_enabled] = value
  end

  def self.env
    @env ||= ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  end
end

# TODO find better ActiveModel hook
ActiveModel::Callbacks.send(:include, Searchkick::Model)
ActiveRecord::Base.send(:extend, Searchkick::Model) if defined?(ActiveRecord)
