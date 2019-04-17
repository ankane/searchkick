require "active_model"
require "elasticsearch"
require "hashie"
require "searchkick/version"
require "searchkick/index_options"
require "searchkick/index"
require "searchkick/indexer"
require "searchkick/results"
require "searchkick/query"
require "searchkick/reindex_job"
require "searchkick/model"
require "searchkick/tasks"
require "searchkick/middleware"
require "searchkick/logging" if defined?(ActiveSupport::Notifications)
require "active_support/core_ext/hash/deep_merge"

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
    attr_accessor :search_method_name, :wordnet_path, :timeout, :models, :client_options
    attr_writer :client, :new_client, :env, :search_timeout
    attr_reader :aws_credentials
  end
  self.search_method_name = :search
  self.wordnet_path = "/var/lib/wn_s.pl"
  self.timeout = 30
  self.models = []
  self.client_options = {}

  def self.client
    @client ||= begin
      require "typhoeus/adapters/faraday" if defined?(Typhoeus)

      Elasticsearch::Client.new({
        url: ENV["ELASTICSEARCH_URL"],
        transport_options: {request: {timeout: timeout}, headers: {content_type: "application/json"}}
      }.deep_merge(client_options)) do |f|
        f.use Searchkick::Middleware
        f.request :aws_signers_v4, {
          credentials: Aws::Credentials.new(aws_credentials[:access_key_id], aws_credentials[:secret_access_key]),
          service_name: "es",
          region: aws_credentials[:region] || "us-east-1"
        } if aws_credentials
      end
    end
  end

  def self.new_client
    new_client_url = ENV["ELASTICSEARCH_WRITE_ONLY_URL"] || ENV["ELASTICSEARCH_NEW_CLIENT_URL"]
    return nil if new_client_url.blank?

    @new_client ||=
      Elasticsearch::Client.new({
        url: new_client_url,
        transport_options: {request: {timeout: timeout}, headers: {content_type: "application/json"}}
      }.deep_merge(client_options)) do |f|
        f.use Searchkick::Middleware
        f.request :aws_signers_v4, {
          credentials: Aws::Credentials.new(aws_credentials[:access_key_id], aws_credentials[:secret_access_key]),
          service_name: "es",
          region: aws_credentials[:region] || "us-east-1"
        } if aws_credentials
      end
  end

  def self.get_current_client_id
    return nil unless Thread.current['search_kick_client_id'].present?
    Thread.current['search_kick_client_id'].to_i
  end

  def self.writing_clients
    current_client = get_current_client_id
    if current_client.present?
      case current_client
      when 1
        [client]
      when 2
        raise Exception, 'new_client not defined' if new_client.nil?
        [new_client]
      else
        raise Exception, 'Invalid value for RequestStoreService.get_current_client_id can be 1 or 2. nil as legacy support'
      end
    end

    return @writing_clients if @writing_clients.present?
    @writing_clients = [client]
    @writing_clients << new_client() if new_client().present?
    @writing_clients
  end

  def self.env
    @env ||= ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  end

  def self.search_timeout
    @search_timeout || timeout
  end

  def self.server_version(is_new_client = false)
    if is_new_client
      @server_version ||= self.new_client.info["version"]["number"]
      return @server_version
    else
      @new_client_server_version ||= self.client.info["version"]["number"]
      return @new_client_server_version
    end
  end

  def self.server_below?(version, is_new_client = false)
    Gem::Version.new(server_version(is_new_client).sub("-", ".")) < Gem::Version.new(version.sub("-", "."))
  end

  def self.search(term = nil, options = {}, &block)
    query = Searchkick::Query.new(nil, term, options)
    block.call(query.body) if block
    if options[:execute] == false
      query
    else
      query.execute
    end
  end

  def self.multi_search(queries)
    if queries.any?
      responses = client.msearch(body: queries.flat_map { |q| [q.params.except(:body), q.body] })["responses"]
      queries.each_with_index do |query, i|
        query.handle_response(responses[i])
      end
    end
    nil
  end

  # callbacks

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
        indexer.perform if callbacks_value == :bulk
      ensure
        self.callbacks_value = previous_value
      end
    else
      self.callbacks_value = value
    end
  end

  def self.aws_credentials=(creds)
    require "faraday_middleware/aws_signers_v4"
    @aws_credentials = creds
    @client = nil # reset client
  end

  # private
  def self.indexer
    Thread.current[:searchkick_indexer] ||= Searchkick::Indexer.new
  end

  # private
  def self.callbacks_value
    Thread.current[:searchkick_callbacks_enabled]
  end

  # private
  def self.callbacks_value=(value)
    Thread.current[:searchkick_callbacks_enabled] = value
  end
end

# TODO find better ActiveModel hook
ActiveModel::Callbacks.send(:include, Searchkick::Model)
ActiveRecord::Base.send(:extend, Searchkick::Model) if defined?(ActiveRecord)
