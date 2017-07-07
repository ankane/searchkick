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
      client.indices.delete index: name
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

    def promote(new_name, update_refresh_interval: false)
      if update_refresh_interval
        new_index = Searchkick::Index.new(new_name)
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

    # record based
    # use helpers for notifications

    def store(record)
      bulk_index_helper([record])
    end

    def remove(record)
      bulk_delete_helper([record])
    end

    def update_record(record, method_name)
      bulk_update_helper([record], method_name)
    end

    def bulk_delete(records)
      bulk_delete_helper(records)
    end

    def bulk_index(records)
      bulk_index_helper(records)
    end
    alias_method :import, :bulk_index

    def bulk_update(records, method_name)
      bulk_update_helper(records, method_name)
    end

    def record_data(r)
      data = {
        _index: name,
        _id: search_id(r),
        _type: document_type(r)
      }
      data[:_routing] = r.search_routing if r.respond_to?(:search_routing)
      data
    end

    def retrieve(record)
      client.get(
        index: name,
        type: document_type(record),
        id: search_id(record)
      )["_source"]
    end

    def reindex_record(record)
      if record.destroyed? || !record.should_index?
        begin
          remove(record)
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          # do nothing
        end
      else
        store(record)
      end
    end

    def reindex_record_async(record)
      if Searchkick.callbacks_value.nil?
        if defined?(Searchkick::ReindexV2Job)
          Searchkick::ReindexV2Job.perform_later(record.class.name, record.id.to_s)
        else
          raise Searchkick::Error, "Active Job not found"
        end
      else
        reindex_record(record)
      end
    end

    def similar_record(record, **options)
      like_text = retrieve(record).to_hash
        .keep_if { |k, _| !options[:fields] || options[:fields].map(&:to_s).include?(k) }
        .values.compact.join(" ")

      # TODO deep merge method
      options[:where] ||= {}
      options[:where][:_id] ||= {}
      options[:where][:_id][:not] = record.id.to_s
      options[:per_page] ||= 10
      options[:similar] = true

      # TODO use index class instead of record class
      search_model(record.class, like_text, options)
    end

    # queue

    def reindex_queue
      Searchkick::ReindexQueue.new(name)
    end

    # search

    # TODO remove in next major version
    def search_model(searchkick_klass, term = "*", **options, &block)
      query = Searchkick::Query.new(searchkick_klass, term, options)
      yield(query.body) if block
      if options[:execute] == false
        query
      else
        query.execute
      end
    end

    # reindex

    def create_index(index_options: nil)
      index_options ||= self.index_options
      index = Searchkick::Index.new("#{name}_#{Time.now.strftime('%Y%m%d%H%M%S%L')}", @options)
      index.create(index_options)
      index
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

    # https://gist.github.com/jarosan/3124884
    # http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/
    def reindex_scope(scope, import: true, resume: false, retain: false, async: false, refresh_interval: nil)
      if resume
        index_name = all_indices.sort.last
        raise Searchkick::Error, "No index to resume" unless index_name
        index = Searchkick::Index.new(index_name)
      else
        clean_indices unless retain

        index_options = scope.searchkick_index_options
        index_options.deep_merge!(settings: {index: {refresh_interval: refresh_interval}}) if refresh_interval
        index = create_index(index_options: index_options)
      end

      # check if alias exists
      if alias_exists?
        # import before promotion
        index.import_scope(scope, resume: resume, async: async, full: true) if import

        # get existing indices to remove
        unless async
          promote(index.name, update_refresh_interval: !refresh_interval.nil?)
          clean_indices unless retain
        end
      else
        delete if exists?
        promote(index.name, update_refresh_interval: !refresh_interval.nil?)

        # import after promotion
        index.import_scope(scope, resume: resume, async: async, full: true) if import
      end

      if async
        {index_name: index.name}
      else
        index.refresh
        true
      end
    end

    def import_scope(scope, resume: false, method_name: nil, async: false, batch: false, batch_id: nil, full: false)
      # use scope for import
      scope = scope.search_import if scope.respond_to?(:search_import)

      if batch
        import_or_update scope.to_a, method_name, async
        Searchkick.with_redis { |r| r.srem(batches_key, batch_id) } if batch_id
      elsif full && async
        full_reindex_async(scope)
      elsif scope.respond_to?(:find_in_batches)
        if resume
          # use total docs instead of max id since there's not a great way
          # to get the max _id without scripting since it's a string

          # TODO use primary key and prefix with table name
          scope = scope.where("id > ?", total_docs)
        end

        scope = scope.select("id").except(:includes, :preload) if async

        scope.find_in_batches batch_size: batch_size do |batch|
          import_or_update batch, method_name, async
        end
      else
        each_batch(scope) do |items|
          import_or_update items, method_name, async
        end
      end
    end

    def batches_left
      Searchkick.with_redis { |r| r.scard(batches_key) }
    end

    # other

    def tokens(text, options = {})
      client.indices.analyze({text: text, index: name}.merge(options))["tokens"].map { |t| t["token"] }
    end

    def klass_document_type(klass)
      @klass_document_type[klass] ||= begin
        if klass.respond_to?(:document_type)
          klass.document_type
        else
          klass.model_name.to_s.underscore
        end
      end
    end

    protected

    def client
      Searchkick.client
    end

    def document_type(record)
      if record.respond_to?(:search_document_type)
        record.search_document_type
      else
        klass_document_type(record.class)
      end
    end

    def search_id(record)
      id = record.respond_to?(:search_document_id) ? record.search_document_id : record.id
      id.is_a?(Numeric) ? id : id.to_s
    end

    EXCLUDED_ATTRIBUTES = ["_id", "_type"]

    def search_data(record, method_name = nil)
      partial_reindex = !method_name.nil?
      options = record.class.searchkick_options

      # remove _id since search_id is used instead
      source = record.send(method_name || :search_data).each_with_object({}) { |(k, v), memo| memo[k.to_s] = v; memo }.except(*EXCLUDED_ATTRIBUTES)

      # conversions
      if options[:conversions]
        Array(options[:conversions]).map(&:to_s).each do |conversions_field|
          if source[conversions_field]
            source[conversions_field] = source[conversions_field].map { |k, v| {query: k, count: v} }
          end
        end
      end

      # hack to prevent generator field doesn't exist error
      if options[:suggest]
        options[:suggest].map(&:to_s).each do |field|
          source[field] = nil if !source[field] && !partial_reindex
        end
      end

      # locations
      if options[:locations]
        options[:locations].map(&:to_s).each do |field|
          if source[field]
            if !source[field].is_a?(Hash) && (source[field].first.is_a?(Array) || source[field].first.is_a?(Hash))
              # multiple locations
              source[field] = source[field].map { |a| location_value(a) }
            else
              source[field] = location_value(source[field])
            end
          end
        end
      end

      cast_big_decimal(source)

      source
    end

    def location_value(value)
      if value.is_a?(Array)
        value.map(&:to_f).reverse
      elsif value.is_a?(Hash)
        {lat: value[:lat].to_f, lon: value[:lon].to_f}
      else
        value
      end
    end

    # change all BigDecimal values to floats due to
    # https://github.com/rails/rails/issues/6033
    # possible loss of precision :/
    def cast_big_decimal(obj)
      case obj
      when BigDecimal
        obj.to_f
      when Hash
        obj.each do |k, v|
          obj[k] = cast_big_decimal(v)
        end
      when Enumerable
        obj.map do |v|
          cast_big_decimal(v)
        end
      else
        obj
      end
    end

    def import_or_update(records, method_name, async)
      if records.any?
        if async
          Searchkick::BulkReindexJob.perform_later(
            class_name: records.first.class.name,
            record_ids: records.map(&:id),
            index_name: name,
            method_name: method_name ? method_name.to_s : nil
          )
        else
          records = records.select(&:should_index?)
          if records.any?
            with_retries do
              method_name ? bulk_update(records, method_name) : import(records)
            end
          end
        end
      end
    end

    def full_reindex_async(scope)
      if scope.respond_to?(:primary_key)
        # TODO expire Redis key
        primary_key = scope.primary_key

        starting_id = scope.minimum(primary_key)
        if starting_id.nil?
          # no records, do nothing
        elsif starting_id.is_a?(Numeric)
          max_id = scope.maximum(primary_key)
          batches_count = ((max_id - starting_id + 1) / batch_size.to_f).ceil

          batches_count.times do |i|
            batch_id = i + 1
            min_id = starting_id + (i * batch_size)
            bulk_reindex_job scope, batch_id, min_id: min_id, max_id: min_id + batch_size - 1
          end
        else
          scope.find_in_batches(batch_size: batch_size).each_with_index do |batch, i|
            batch_id = i + 1

            bulk_reindex_job scope, batch_id, record_ids: batch.map { |record| record.id.to_s }
          end
        end
      else
        batch_id = 1
        # TODO remove any eager loading
        scope = scope.only(:_id) if scope.respond_to?(:only)
        each_batch(scope) do |items|
          bulk_reindex_job scope, batch_id, record_ids: items.map { |i| i.id.to_s }
          batch_id += 1
        end
      end
    end

    def each_batch(scope)
      # https://github.com/karmi/tire/blob/master/lib/tire/model/import.rb
      # use cursor for Mongoid
      items = []
      scope.all.each do |item|
        items << item
        if items.length == batch_size
          yield items
          items = []
        end
      end
      yield items if items.any?
    end

    def bulk_reindex_job(scope, batch_id, options)
      Searchkick::BulkReindexJob.perform_later({
        class_name: scope.model_name.name,
        index_name: name,
        batch_id: batch_id
      }.merge(options))
      Searchkick.with_redis { |r| r.sadd(batches_key, batch_id) }
    end

    def batch_size
      @batch_size ||= @options[:batch_size] || 1000
    end

    def with_retries
      retries = 0

      begin
        yield
      rescue Faraday::ClientError => e
        if retries < 1
          retries += 1
          retry
        end
        raise e
      end
    end

    def bulk_index_helper(records)
      Searchkick.indexer.queue(records.map { |r| {index: record_data(r).merge(data: search_data(r))} })
    end

    def bulk_delete_helper(records)
      Searchkick.indexer.queue(records.reject { |r| r.id.blank? }.map { |r| {delete: record_data(r)} })
    end

    def bulk_update_helper(records, method_name)
      Searchkick.indexer.queue(records.map { |r| {update: record_data(r).merge(data: {doc: search_data(r, method_name)})} })
    end

    def batches_key
      "searchkick:reindex:#{name}:batches"
    end
  end
end
