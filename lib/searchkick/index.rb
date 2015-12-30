require "searchkick/index/records"
require "searchkick/index/options"

module Searchkick
  class Index
    include Searchkick::Helpers
    include Records
    include Options

    attr_reader :name, :options, :settings

    def initialize(name, options = {})
      @name = name
      @options = options
    end

    def create(options = {})
      client.indices.create index: name, body: options
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

    def swap(new_name)
      old_indices =
        begin
          client.indices.get_alias(name: name).keys
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          []
        end
      actions = old_indices.map { |old_name| {remove: {index: old_name, alias: name}} } + [{add: {index: new_name, alias: name}}]
      client.indices.update_aliases body: {actions: actions}
    end

    # search

    def search_model(searchkick_klass, term = nil, options = {}, &block)
      query = Searchkick::Query.new(searchkick_klass, term, options)
      block.call(query.body) if block
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

    # remove old indices that start w/ index_name
    def clean_indices
      all_indices = client.indices.get_aliases
      indices = all_indices.select { |k, v| (v.empty? || v["aliases"].empty?) && k =~ /\A#{Regexp.escape(name)}_\d{14,17}\z/ }.keys
      indices.each do |index|
        Searchkick::Index.new(index).delete
      end
      indices
    end

    # https://gist.github.com/jarosan/3124884
    # http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/
    def reindex_scope(scope, options = {})
      skip_import = options[:import] == false

      clean_indices

      index = create_index(index_options: scope.searchkick_index_options)

      # check if alias exists
      if alias_exists?
        # import before swap
        index.import_scope(scope) unless skip_import

        # get existing indices to remove
        swap(index.name)
        clean_indices
      else
        delete if exists?
        swap(index.name)

        # import after swap
        index.import_scope(scope) unless skip_import
      end

      index.refresh

      true
    end

    def import_scope(scope)
      batch_size = @options[:batch_size] || 1000

      # use scope for import
      scope = scope.search_import if scope.respond_to?(:search_import)
      if scope.respond_to?(:find_in_batches)
        scope.find_in_batches batch_size: batch_size do |batch|
          import batch.select(&:should_index?)
        end
      else
        # https://github.com/karmi/tire/blob/master/lib/tire/model/import.rb
        # use cursor for Mongoid
        items = []
        scope.all.each do |item|
          items << item if item.should_index?
          if items.length == batch_size
            import items
            items = []
          end
        end
        import items
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

    def document_type(record)
      klass_document_type(record.class)
    end

    def search_id(record)
      record.id.is_a?(Numeric) ? record.id : record.id.to_s
    end

    def search_data(record)
      source = record.search_data
      options = record.class.searchkick_options

      # stringify fields
      # remove _id since search_id is used instead
      source = source.inject({}) { |memo, (k, v)| memo[k.to_s] = v; memo }.except("_id")

      # conversions
      conversions_field = options[:conversions]
      if conversions_field && source[conversions_field]
        source[conversions_field] = source[conversions_field].map { |k, v| {query: k, count: v} }
      end

      # hack to prevent generator field doesn't exist error
      map_to_string(options[:suggest]).each do |field|
        source[field] = nil unless source[field]
      end

      # locations
      map_to_string(options[:locations]).each do |field|
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
  end
end
