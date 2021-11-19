# dependencies
require "active_support"
require "active_support/core_ext/hash/deep_merge"
require "elasticsearch"
require "hashie"

# modules
require "searchkick/bulk_indexer"
require "searchkick/index"
require "searchkick/indexer"
require "searchkick/hash_wrapper"
require "searchkick/middleware"
require "searchkick/model"
require "searchkick/multi_search"
require "searchkick/query"
require "searchkick/reindex_queue"
require "searchkick/record_data"
require "searchkick/record_indexer"
require "searchkick/results"
require "searchkick/version"

# integrations
require "searchkick/railtie" if defined?(Rails)
require "searchkick/logging" if defined?(ActiveSupport::Notifications)

module Searchkick
  # background jobs
  autoload :BulkReindexJob,  "searchkick/bulk_reindex_job"
  autoload :ProcessBatchJob, "searchkick/process_batch_job"
  autoload :ProcessQueueJob, "searchkick/process_queue_job"
  autoload :ReindexV2Job,    "searchkick/reindex_v2_job"

  # errors
  class Error < StandardError; end
  class MissingIndexError < Error; end
  class UnsupportedVersionError < Error; end
  # TODO switch to Error
  class InvalidQueryError < Elasticsearch::Transport::Transport::Errors::BadRequest; end
  class DangerousOperation < Error; end
  class ImportError < Error; end

  class << self
    attr_accessor :search_method_name, :wordnet_path, :timeout, :models, :client_options, :redis, :index_prefix, :index_suffix, :queue_name, :model_options
    attr_writer :client, :env, :search_timeout
    attr_reader :aws_credentials
  end
  self.search_method_name = :search
  self.wordnet_path = "/var/lib/wn_s.pl"
  self.timeout = 10
  self.models = []
  self.client_options = {}
  self.queue_name = :searchkick
  self.model_options = {}

  def self.client
    @client ||= begin
      require "typhoeus/adapters/faraday" if defined?(Typhoeus) && Gem::Version.new(Faraday::VERSION) < Gem::Version.new("0.14.0")

      Elasticsearch::Client.new({
        url: ENV["ELASTICSEARCH_URL"] || ENV["OPENSEARCH_URL"],
        transport_options: {request: {timeout: timeout}, headers: {content_type: "application/json"}},
        retry_on_failure: 2
      }.deep_merge(client_options)) do |f|
        f.use Searchkick::Middleware
        f.request signer_middleware_key, signer_middleware_aws_params if aws_credentials
      end
    end
  end

  def self.env
    @env ||= ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
  end

  def self.search_timeout
    (defined?(@search_timeout) && @search_timeout) || timeout
  end

  # private
  def self.server_info
    @server_info ||= client.info
  end

  def self.server_version
    @server_version ||= server_info["version"]["number"]
  end

  def self.opensearch?
    unless defined?(@opensearch)
      @opensearch = server_info["version"]["distribution"] == "opensearch"
    end
    @opensearch
  end

  def self.server_below?(version)
    server_version = opensearch? ? "7.10.2" : self.server_version
    Gem::Version.new(server_version.split("-")[0]) < Gem::Version.new(version.split("-")[0])
  end

  # memoize for performance
  def self.server_below7?
    unless defined?(@server_below7)
      @server_below7 = server_below?("7.0.0")
    end
    @server_below7
  end

  def self.search(term = "*", model: nil, **options, &block)
    options = options.dup
    klass = model

    # convert index_name into models if possible
    # this should allow for easier upgrade
    if options[:index_name] && !options[:models] && Array(options[:index_name]).all? { |v| v.respond_to?(:searchkick_index) }
      options[:models] = options.delete(:index_name)
    end

    # make Searchkick.search(models: [Product]) and Product.search equivalent
    unless klass
      models = Array(options[:models])
      if models.size == 1
        klass = models.first
        options.delete(:models)
      end
    end

    if klass
      if (options[:models] && Array(options[:models]) != [klass]) || Array(options[:index_name]).any? { |v| v.respond_to?(:searchkick_index) && v != klass }
        raise ArgumentError, "Use Searchkick.search to search multiple models"
      end
    end

    options = options.merge(block: block) if block
    query = Searchkick::Query.new(klass, term, **options)
    if options[:execute] == false
      query
    else
      query.execute
    end
  end

  def self.multi_search(queries)
    Searchkick::MultiSearch.new(queries).perform
  end

  # callbacks

  def self.enable_callbacks
    self.callbacks_value = nil
  end

  def self.disable_callbacks
    self.callbacks_value = false
  end

  def self.callbacks?(default: true)
    if callbacks_value.nil?
      default
    else
      callbacks_value != false
    end
  end

  def self.callbacks(value = nil)
    if block_given?
      previous_value = callbacks_value
      begin
        self.callbacks_value = value
        result = yield
        indexer.perform if callbacks_value == :bulk
        result
      ensure
        self.callbacks_value = previous_value
      end
    else
      self.callbacks_value = value
    end
  end

  def self.aws_credentials=(creds)
    begin
      # TODO remove in Searchkick 5 (just use aws_sigv4)
      require "faraday_middleware/aws_signers_v4"
    rescue LoadError
      require "faraday_middleware/aws_sigv4"
    end
    @aws_credentials = creds
    @client = nil # reset client
  end

  def self.reindex_status(index_name)
    raise Searchkick::Error, "Redis not configured" unless redis

    batches_left = Searchkick::Index.new(index_name).batches_left
    {
      completed: batches_left == 0,
      batches_left: batches_left
    }
  end

  # TODO use ConnectionPool::Wrapper when redis is set so this is no longer needed
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

  def self.warn(message)
    super("[searchkick] WARNING: #{message}")
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

  # private
  def self.signer_middleware_key
    defined?(FaradayMiddleware::AwsSignersV4) ? :aws_signers_v4 : :aws_sigv4
  end

  # private
  def self.signer_middleware_aws_params
    if signer_middleware_key == :aws_sigv4
      {service: "es", region: "us-east-1"}.merge(aws_credentials)
    else
      {
        credentials: aws_credentials[:credentials] || Aws::Credentials.new(aws_credentials[:access_key_id], aws_credentials[:secret_access_key]),
        service_name: "es",
        region: aws_credentials[:region] || "us-east-1"
      }
    end
  end

  # private
  # methods are forwarded to base class
  # this check to see if scope exists on that class
  # it's a bit tricky, but this seems to work
  def self.relation?(klass)
    if klass.respond_to?(:current_scope)
      !klass.current_scope.nil?
    elsif defined?(Mongoid::Threaded)
      !Mongoid::Threaded.current_scope(klass).nil?
    end
  end

  # private
  def self.not_found_error?(e)
    (defined?(Elasticsearch) && e.is_a?(Elasticsearch::Transport::Transport::Errors::NotFound)) ||
    (defined?(OpenSearch) && e.is_a?(OpenSearch::Transport::Transport::Errors::NotFound))
  end

  # private
  def self.transport_error?(e)
    (defined?(Elasticsearch) && e.is_a?(Elasticsearch::Transport::Transport::Error)) ||
    (defined?(OpenSearch) && e.is_a?(OpenSearch::Transport::Transport::Error))
  end
end

require "active_model/callbacks"
ActiveModel::Callbacks.include(Searchkick::Model)
# TODO use
# ActiveSupport.on_load(:mongoid) do
#   Mongoid::Document::ClassMethods.include Searchkick::Model
# end

ActiveSupport.on_load(:active_record) do
  extend Searchkick::Model
end
