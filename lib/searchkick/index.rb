require "searchkick/index_options"

module Searchkick
  class Index
    include IndexOptions

    attr_reader :name, :options

    def initialize(name, options = {})
      @name = name
      @options = options
      @klass_document_type = {} # cache
    end

    def create(body = {})
      client.indices.create index: name, body: body
    end

    def delete
      if !Searchkick.server_below?("6.0.0") && alias_exists?
        # can't call delete directly on aliases in ES 6
        indices = client.indices.get_alias(name: name).keys
        client.indices.delete index: indices
      else
        client.indices.delete index: name
      end
    end

    def exists?
      client.indices.exists index: name
    end

    def refresh
      client.indices.refresh index: name
    end

    def alias_exists?
      client.indices.exists_alias name: name
    end

    def mapping
      client.indices.get_mapping index: name
    end

    def settings
      client.indices.get_settings index: name
    end

    def refresh_interval
      settings.values.first["settings"]["index"]["refresh_interval"]
    end

    def update_settings(settings)
      client.indices.put_settings index: name, body: settings
    end

    def tokens(text, options = {})
      client.indices.analyze(body: {text: text}.merge(options), index: name)["tokens"].map { |t| t["token"] }
    end

    def total_docs
      response =
        client.search(
          index: name,
          body: {
            query: {match_all: {}},
            size: 0
          }
        )

      response["hits"]["total"]
    end

    def promote(new_name, update_refresh_interval: false)
      if update_refresh_interval
        new_index = Searchkick::Index.new(new_name, @options)
        settings = options[:settings] || {}
        refresh_interval = (settings[:index] && settings[:index][:refresh_interval]) || "1s"
        new_index.update_settings(index: {refresh_interval: refresh_interval})
      end

      old_indices =
        begin
          client.indices.get_alias(name: name).keys
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          {}
        end
      actions = old_indices.map { |old_name| {remove: {index: old_name, alias: name}} } + [{add: {index: new_name, alias: name}}]
      client.indices.update_aliases body: {actions: actions}
    end
    alias_method :swap, :promote

    def retrieve(record)
      client.get(
        index: name,
        type: document_type(record),
        id: search_id(record)
      )["_source"]
    end

    def all_indices(unaliased: false)
      indices =
        begin
          client.indices.get_aliases
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          {}
        end
      indices = indices.select { |_k, v| v.empty? || v["aliases"].empty? } if unaliased
      indices.select { |k, _v| k =~ /\A#{Regexp.escape(name)}_\d{14,17}\z/ }.keys
    end

    # remove old indices that start w/ index_name
    def clean_indices
      indices = all_indices(unaliased: true)
      indices.each do |index|
        Searchkick::Index.new(index).delete
      end
      indices
    end

    # record based
    # use helpers for notifications

    def store(record)
      bulk_indexer.bulk_index([record])
    end

    def remove(record)
      bulk_indexer.bulk_delete([record])
    end

    def update_record(record, method_name)
      bulk_indexer.bulk_update([record], method_name)
    end

    def bulk_delete(records)
      bulk_indexer.bulk_delete(records)
    end

    def bulk_index(records)
      bulk_indexer.bulk_index(records)
    end
    alias_method :import, :bulk_index

    def bulk_update(records, method_name)
      bulk_indexer.bulk_update(records, method_name)
    end

    def search_id(record)
      RecordData.new(self, record).search_id
    end

    def document_type(record)
      RecordData.new(self, record).document_type
    end

    def similar_record(record, **options)
      like_text = retrieve(record).to_hash
        .keep_if { |k, _| !options[:fields] || options[:fields].map(&:to_s).include?(k) }
        .values.compact.join(" ")

      options[:where] ||= {}
      options[:where][:_id] ||= {}
      options[:where][:_id][:not] = Array(options[:where][:_id][:not]) + [record.id.to_s]
      options[:per_page] ||= 10
      options[:similar] = true

      # TODO use index class instead of record class
      Searchkick.search(like_text, model: record.class, **options)
    end

    # queue

    def reindex_queue
      Searchkick::ReindexQueue.new(name)
    end

    # reindex

    def reindex(relation, method_name, scoped:, full: false, scope: nil, **options)
      refresh = options.fetch(:refresh, !scoped)

      if method_name
        # update
        import_scope(relation, method_name: method_name, scope: scope)
        self.refresh if refresh
        true
      elsif scoped && !full
        # reindex association
        import_scope(relation, scope: scope)
        self.refresh if refresh
        true
      else
        # full reindex
        reindex_scope(relation, scope: scope, **options)
      end
    end

    def create_index(index_options: nil)
      index_options ||= self.index_options
      index = Searchkick::Index.new("#{name}_#{Time.now.strftime('%Y%m%d%H%M%S%L')}", @options)
      index.create(index_options)
      index
    end

    def import_scope(relation, **options)
      bulk_indexer.import_scope(relation, **options)
    end

    def batches_left
      bulk_indexer.batches_left
    end

    # other

    def klass_document_type(klass, ignore_type = false)
      @klass_document_type[[klass, ignore_type]] ||= begin
        if !ignore_type && klass.searchkick_klass.searchkick_options[:_type]
          type = klass.searchkick_klass.searchkick_options[:_type]
          type = type.call if type.respond_to?(:call)
          type
        else
          klass.model_name.to_s.underscore
        end
      end
    end

    # should not be public
    def conversions_fields
      @conversions_fields ||= begin
        conversions = Array(options[:conversions])
        conversions.map(&:to_s) + conversions.map(&:to_sym)
      end
    end

    def suggest_fields
      @suggest_fields ||= Array(options[:suggest]).map(&:to_s)
    end

    def locations_fields
      @locations_fields ||= begin
        locations = Array(options[:locations])
        locations.map(&:to_s) + locations.map(&:to_sym)
      end
    end

    protected

    def client
      Searchkick.client
    end

    def bulk_indexer
      @bulk_indexer ||= BulkIndexer.new(self)
    end

    # https://gist.github.com/jarosan/3124884
    # http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/
    def reindex_scope(relation, import: true, resume: false, retain: false, async: false, refresh_interval: nil, scope: nil)
      if resume
        index_name = all_indices.sort.last
        raise Searchkick::Error, "No index to resume" unless index_name
        index = Searchkick::Index.new(index_name, @options)
      else
        clean_indices unless retain

        index_options = relation.searchkick_index_options
        index_options.deep_merge!(settings: {index: {refresh_interval: refresh_interval}}) if refresh_interval
        index = create_index(index_options: index_options)
      end

      import_options = {
        resume: resume,
        async: async,
        full: true,
        scope: scope
      }

      # check if alias exists
      alias_exists = alias_exists?
      if alias_exists
        # import before promotion
        index.import_scope(relation, **import_options) if import

        # get existing indices to remove
        unless async
          promote(index.name, update_refresh_interval: !refresh_interval.nil?)
          clean_indices unless retain
        end
      else
        delete if exists?
        promote(index.name, update_refresh_interval: !refresh_interval.nil?)

        # import after promotion
        index.import_scope(relation, **import_options) if import
      end

      if async
        if async.is_a?(Hash) && async[:wait]
          puts "Created index: #{index.name}"
          puts "Jobs queued. Waiting..."
          loop do
            sleep 3
            status = Searchkick.reindex_status(index.name)
            break if status[:completed]
            puts "Batches left: #{status[:batches_left]}"
          end
          # already promoted if alias didn't exist
          if alias_exists
            puts "Jobs complete. Promoting..."
            promote(index.name, update_refresh_interval: !refresh_interval.nil?)
          end
          clean_indices unless retain
          puts "SUCCESS!"
        end

        {index_name: index.name}
      else
        index.refresh
        true
      end
    rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
      if e.message.include?("No handler for type [text]")
        raise UnsupportedVersionError, "This version of Searchkick requires Elasticsearch 5 or greater"
      end

      raise e
    end
  end
end
