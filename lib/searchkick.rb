require "active_model"
require "elasticsearch"
require "hashie"
require "searchkick/version"
require "searchkick/index_options"
require "searchkick/index"
require "searchkick/indexer"
require "searchkick/reindex_queue"
require "searchkick/results"
require "searchkick/query"
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
if defined?(ActiveJob)
  require "searchkick/bulk_reindex_job"
  require "searchkick/process_queue_job"
  require "searchkick/process_batch_job"
  require "searchkick/reindex_v2_job"
end

module Searchkick
  class Error < StandardError; end
  class MissingIndexError < Error; end
  class UnsupportedVersionError < Error; end
  class InvalidQueryError < Elasticsearch::Transport::Transport::Errors::BadRequest; end
  class DangerousOperation < Error; end
  class ImportError < Error; end

  class << self
    attr_accessor :search_method_name, :wordnet_path, :timeout, :models, :client_options, :redis, :index_suffix, :queue_name
    attr_writer :client, :env, :search_timeout
    attr_reader :aws_credentials
  end
  self.search_method_name = :search
  self.wordnet_path = "/var/lib/wn_s.pl"
  self.timeout = 10
  self.models = []
  self.client_options = {}
  self.queue_name = :searchkick

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

  def self.env
    @env ||= ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  end

  def self.search_timeout
    @search_timeout || timeout
  end

  def self.server_version
    @server_version ||= client.info["version"]["number"]
  end

  def self.server_below?(version)
    Gem::Version.new(server_version.sub("-", ".")) < Gem::Version.new(version.sub("-", "."))
  end

  def self.search(term = "*", **options, &block)
    klass = options[:model]

    # TODO add in next major version
    # if !klass
    #   index_name = Array(options[:index_name])
    #   if index_name.size == 1 && index_name.first.respond_to?(:searchkick_index)
    #     klass = index_name.first
    #   end
    # end

    query = Searchkick::Query.new(klass, term, options.except(:model))
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
    queries
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

  def self.reindex_status(index_name)
    if redis
      batches_left = Searchkick::Index.new(index_name).batches_left
      {
        completed: batches_left == 0,
        batches_left: batches_left
      }
    end
  end

  def self.with_redis
    if redis
      if redis.respond_to?(:with)
        redis.with do |r|
          yield r
        end
      else
        yield redis
      end
    end
  end

  # private
  def self.load_records(records, ids)
    records =
      if records.respond_to?(:primary_key)
        # ActiveRecord
        records.where(records.primary_key => ids) if records.primary_key
      elsif records.respond_to?(:queryable)
        # Mongoid 3+
        records.queryable.for_ids(ids)
      elsif records.respond_to?(:unscoped) && :id.respond_to?(:in)
        # Nobrainer
        records.unscoped.where(:id.in => ids)
      elsif records.respond_to?(:key_column_names)
        records.where(records.key_column_names.first => ids)
      end

    raise Searchkick::Error, "Not sure how to load records" if !records

    records
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

ActiveSupport.on_load(:active_record) do
  extend Searchkick::Model
end
