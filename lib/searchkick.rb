require "active_model"
require "elasticsearch"
require "hashie"
require "searchkick/version"
require "searchkick/index"
require "searchkick/reindex"
require "searchkick/results"
require "searchkick/query"
require "searchkick/similar"
require "searchkick/model"
require "searchkick/tasks"
require "searchkick/logging" if defined?(Rails)

module Searchkick
  class MissingIndexError < StandardError; end
  class UnsupportedVersionError < StandardError; end
  class InvalidQueryError < Elasticsearch::Transport::Transport::Errors::BadRequest; end

  class << self
    attr_accessor :callbacks
    attr_accessor :search_method_name
    attr_accessor :wordnet_path
    attr_accessor :reindex_job
    attr_accessor :backend
  end
  self.callbacks = true
  self.search_method_name = :search
  self.wordnet_path = "/var/lib/wn_s.pl"

  def self.enqueue(klass, id)
    backend.enqueue klass, id
  end

  def self.client
    @client ||= Elasticsearch::Client.new(url: ENV["ELASTICSEARCH_URL"])
  end

  def self.client=(client)
    @client = client
  end

  def self.server_version
    @server_version ||= client.info["version"]["number"]
  end

  def self.enable_callbacks
    self.callbacks = true
  end

  def self.disable_callbacks
    self.callbacks = false
  end

  def self.callbacks?
    callbacks
  end
end

# TODO find better ActiveModel hook
ActiveModel::Callbacks.send(:include, Searchkick::Model)
ActiveRecord::Base.send(:extend, Searchkick::Model) if defined?(ActiveRecord)
