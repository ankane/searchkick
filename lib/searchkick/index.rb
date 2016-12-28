module Searchkick
  class Index
    include IndexOptions

    attr_reader :name, :options

    def initialize(name, options = {})
      @name = name
      @options = options
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

    def swap(new_name)
      old_indices =
        begin
          client.indices.get_alias(name: name).keys
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          {}
        end
      actions = old_indices.map { |old_name| {remove: {index: old_name, alias: name}} } + [{add: {index: new_name, alias: name}}]
      client.indices.update_aliases body: {actions: actions}
    end

    # record based

    def store(record)
      bulk_index([record])
    end

    def remove(record)
      bulk_delete([record])
    end

    def bulk_delete(records)
      Searchkick.indexer.queue(records.reject { |r| r.id.blank? }.map { |r| {delete: record_data(r)} })
    end

    def bulk_index(records)
      Searchkick.indexer.queue(records.map { |r| {index: record_data(r).merge(data: search_data(r))} })
    end
    alias_method :import, :bulk_index

    def bulk_update(records, method_name)
      Searchkick.indexer.queue(records.map { |r| {update: record_data(r).merge(data: {doc: search_data(r, method_name)})} })
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
        elsif defined?(Delayed::Job)
          Delayed::Job.enqueue Searchkick::ReindexJob.new(record.class.name, record.id.to_s)
        else
          raise Searchkick::Error, "Job adapter not found"
        end
      else
        reindex_record(record)
      end
    end

    def similar_record(record, options = {})
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

    # search

    def search_model(searchkick_klass, term = nil, options = {}, &block)
      query = Searchkick::Query.new(searchkick_klass, term, options)
      yield(query.body) if block
      if options[:execute] == false
        query
      else
        query.execute
      end
    end

    # reindex

    def create_index(options = {})
      index_options = options[:index_options] || self.index_options
      index = Searchkick::Index.new("#{name}_#{Time.now.strftime('%Y%m%d%H%M%S%L')}", @options)
      index.create(index_options)
      index
    end

    def all_indices(options = {})
      indices =
        begin
          client.indices.get_aliases
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          {}
        end
      indices = indices.select { |_k, v| v.empty? || v["aliases"].empty? } if options[:unaliased]
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
    def reindex_scope(scope, options = {})
      skip_import = options[:import] == false
      resume = options[:resume]

      if resume
        index_name = all_indices.sort.last
        raise Searchkick::Error, "No index to resume" unless index_name
        index = Searchkick::Index.new(index_name)
      else
        clean_indices

        index = create_index(index_options: scope.searchkick_index_options)
      end

      # check if alias exists
      if alias_exists?
        # import before swap
        index.import_scope(scope, resume: resume) unless skip_import

        # get existing indices to remove
        swap(index.name)
        clean_indices
      else
        delete if exists?
        swap(index.name)

        # import after swap
        index.import_scope(scope, resume: resume) unless skip_import
      end

      index.refresh

      true
    end

    def import_scope(scope, options = {})
      batch_size = @options[:batch_size] || 1000
      method_name = options[:method_name]

      # use scope for import
      scope = scope.search_import if scope.respond_to?(:search_import)
      if scope.respond_to?(:find_in_batches)
        if options[:resume]
          # use total docs instead of max id since there's not a great way
          # to get the max _id without scripting since it's a string

          # TODO use primary key and prefix with table name
          scope = scope.where("id > ?", total_docs)
        end

        scope.find_in_batches batch_size: batch_size do |batch|
          import_or_update batch.select(&:should_index?), method_name
        end
      else
        # https://github.com/karmi/tire/blob/master/lib/tire/model/import.rb
        # use cursor for Mongoid
        items = []
        # TODO add resume
        scope.all.each do |item|
          items << item if item.should_index?
          if items.length == batch_size
            import_or_update items, method_name
            items = []
          end
        end
        import_or_update items, method_name
      end
    end

    def import_or_update(records, method_name)
      retries = 0
      begin
        method_name ? bulk_update(records, method_name) : import(records)
      rescue Faraday::ClientError => e
        if retries < 1
          retries += 1
          retry
        end
        raise e
      end
    end

    # other

    def tokens(text, options = {})
      client.indices.analyze({text: text, index: name}.merge(options))["tokens"].map { |t| t["token"] }
    end

    def klass_document_type(klass)
      if klass.respond_to?(:document_type)
        klass.document_type
      else
        klass.model_name.to_s.underscore
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

    def search_data(record, method_name = nil)
      partial_reindex = !method_name.nil?
      source = record.send(method_name || :search_data)
      options = record.class.searchkick_options

      # stringify fields
      # remove _id since search_id is used instead
      source = source.each_with_object({}) { |(k, v), memo| memo[k.to_s] = v; memo }.except("_id", "_type")

      # conversions
      Array(options[:conversions]).map(&:to_s).each do |conversions_field|
        if source[conversions_field]
          source[conversions_field] = source[conversions_field].map { |k, v| {query: k, count: v} }
        end
      end

      # hack to prevent generator field doesn't exist error
      (options[:suggest] || []).map(&:to_s).each do |field|
        source[field] = nil if !source[field] && !partial_reindex
      end

      # locations
      (options[:locations] || []).map(&:to_s).each do |field|
        if source[field]
          if !source[field].is_a?(Hash) && (source[field].first.is_a?(Array) || source[field].first.is_a?(Hash))
            # multiple locations
            source[field] = source[field].map { |a| location_value(a) }
          else
            source[field] = location_value(source[field])
          end
        end
      end

      cast_big_decimal(source)

      source.as_json
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
  end
end
