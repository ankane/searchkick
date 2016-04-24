module Searchkick
  class Index
    attr_reader :name, :options

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
      Searchkick.queue_items(records.reject { |r| r.id.blank? }.map { |r| {delete: record_data(r)} })
    end

    def bulk_index(records)
      Searchkick.queue_items(records.map { |r| {index: record_data(r).merge(data: search_data(r))} })
    end
    alias_method :import, :bulk_index

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
          Delayed::Job.enqueue Searchkick::ReindexJob.new(record.class.name, record.id.to_s)
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
      all_indices =
        begin
          client.indices.get_aliases
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          {}
        end
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

    def index_options
      options = @options
      language = options[:language]
      language = language.call if language.respond_to?(:call)

      if options[:mappings] && !options[:merge_mappings]
        settings = options[:settings] || {}
        mappings = options[:mappings]
      else
        settings = {
          analysis: {
            analyzer: {
              searchkick_keyword: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase"] + (options[:stem_conversions] == false ? [] : ["searchkick_stemmer"])
              },
              default_index: {
                type: "custom",
                # character filters -> tokenizer -> token filters
                # https://www.elastic.co/guide/en/elasticsearch/guide/current/analysis-intro.html
                char_filter: ["ampersand"],
                tokenizer: "standard",
                # synonym should come last, after stemming and shingle
                # shingle must come before searchkick_stemmer
                filter: ["standard", "lowercase", "asciifolding", "searchkick_index_shingle", "searchkick_stemmer"]
              },
              searchkick_search: {
                type: "custom",
                char_filter: ["ampersand"],
                tokenizer: "standard",
                filter: ["standard", "lowercase", "asciifolding", "searchkick_search_shingle", "searchkick_stemmer"]
              },
              searchkick_search2: {
                type: "custom",
                char_filter: ["ampersand"],
                tokenizer: "standard",
                filter: ["standard", "lowercase", "asciifolding", "searchkick_stemmer"]
              },
              # https://github.com/leschenko/elasticsearch_autocomplete/blob/master/lib/elasticsearch_autocomplete/analyzers.rb
              searchkick_autocomplete_index: {
                type: "custom",
                tokenizer: "searchkick_autocomplete_ngram",
                filter: ["lowercase", "asciifolding"]
              },
              searchkick_autocomplete_search: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding"]
              },
              searchkick_word_search: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding"]
              },
              searchkick_suggest_index: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding", "searchkick_suggest_shingle"]
              },
              searchkick_text_start_index: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding", "searchkick_edge_ngram"]
              },
              searchkick_text_middle_index: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding", "searchkick_ngram"]
              },
              searchkick_text_end_index: {
                type: "custom",
                tokenizer: "keyword",
                filter: ["lowercase", "asciifolding", "reverse", "searchkick_edge_ngram", "reverse"]
              },
              searchkick_word_start_index: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding", "searchkick_edge_ngram"]
              },
              searchkick_word_middle_index: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding", "searchkick_ngram"]
              },
              searchkick_word_end_index: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "asciifolding", "reverse", "searchkick_edge_ngram", "reverse"]
              }
            },
            filter: {
              searchkick_index_shingle: {
                type: "shingle",
                token_separator: ""
              },
              # lucky find http://web.archiveorange.com/archive/v/AAfXfQ17f57FcRINsof7
              searchkick_search_shingle: {
                type: "shingle",
                token_separator: "",
                output_unigrams: false,
                output_unigrams_if_no_shingles: true
              },
              searchkick_suggest_shingle: {
                type: "shingle",
                max_shingle_size: 5
              },
              searchkick_edge_ngram: {
                type: "edgeNGram",
                min_gram: 1,
                max_gram: 50
              },
              searchkick_ngram: {
                type: "nGram",
                min_gram: 1,
                max_gram: 50
              },
              searchkick_stemmer: {
                # use stemmer if language is lowercase, snowball otherwise
                # TODO deprecate language option in favor of stemmer
                type: language == language.to_s.downcase ? "stemmer" : "snowball",
                language: language || "English"
              }
            },
            char_filter: {
              # https://www.elastic.co/guide/en/elasticsearch/guide/current/custom-analyzers.html
              # &_to_and
              ampersand: {
                type: "mapping",
                mappings: ["&=> and "]
              }
            },
            tokenizer: {
              searchkick_autocomplete_ngram: {
                type: "edgeNGram",
                min_gram: 1,
                max_gram: 50
              }
            }
          }
        }

        if Searchkick.env == "test"
          settings.merge!(number_of_shards: 1, number_of_replicas: 0)
        end

        if options[:similarity]
          settings[:similarity] = {default: {type: options[:similarity]}}
        end

        settings.deep_merge!(options[:settings] || {})

        # synonyms
        synonyms = options[:synonyms] || []

        synonyms = synonyms.call if synonyms.respond_to?(:call)

        if synonyms.any?
          settings[:analysis][:filter][:searchkick_synonym] = {
            type: "synonym",
            synonyms: synonyms.select { |s| s.size > 1 }.map { |s| s.join(",") }
          }
          # choosing a place for the synonym filter when stemming is not easy
          # https://groups.google.com/forum/#!topic/elasticsearch/p7qcQlgHdB8
          # TODO use a snowball stemmer on synonyms when creating the token filter

          # http://elasticsearch-users.115913.n3.nabble.com/synonym-multi-words-search-td4030811.html
          # I find the following approach effective if you are doing multi-word synonyms (synonym phrases):
          # - Only apply the synonym expansion at index time
          # - Don't have the synonym filter applied search
          # - Use directional synonyms where appropriate. You want to make sure that you're not injecting terms that are too general.
          settings[:analysis][:analyzer][:default_index][:filter].insert(4, "searchkick_synonym")
          settings[:analysis][:analyzer][:default_index][:filter] << "searchkick_synonym"

          %w(word_start word_middle word_end).each do |type|
            settings[:analysis][:analyzer]["searchkick_#{type}_index".to_sym][:filter].insert(2, "searchkick_synonym")
          end
        end

        if options[:wordnet]
          settings[:analysis][:filter][:searchkick_wordnet] = {
            type: "synonym",
            format: "wordnet",
            synonyms_path: Searchkick.wordnet_path
          }

          settings[:analysis][:analyzer][:default_index][:filter].insert(4, "searchkick_wordnet")
          settings[:analysis][:analyzer][:default_index][:filter] << "searchkick_wordnet"

          %w(word_start word_middle word_end).each do |type|
            settings[:analysis][:analyzer]["searchkick_#{type}_index".to_sym][:filter].insert(2, "searchkick_wordnet")
          end
        end

        if options[:special_characters] == false
          settings[:analysis][:analyzer].each do |_, analyzer_settings|
            analyzer_settings[:filter].reject! { |f| f == "asciifolding" }
          end
        end

        mapping = {}

        # conversions
        if (conversions_field = options[:conversions])
          mapping[conversions_field] = {
            type: "nested",
            properties: {
              query: {type: "string", analyzer: "searchkick_keyword"},
              count: {type: "integer"}
            }
          }
        end

        mapping_options = Hash[
          [:autocomplete, :suggest, :word, :text_start, :text_middle, :text_end, :word_start, :word_middle, :word_end, :highlight, :searchable, :only_analyzed]
            .map { |type| [type, (options[type] || []).map(&:to_s)] }
        ]

        word = options[:word] != false && (!options[:match] || options[:match] == :word)

        mapping_options.values.flatten.uniq.each do |field|
          field_mapping = {
            type: "multi_field",
            fields: {}
          }

          unless mapping_options[:only_analyzed].include?(field)
            field_mapping[:fields][field] = {type: "string", index: "not_analyzed"}
          end

          if !options[:searchable] || mapping_options[:searchable].include?(field)
            if word
              field_mapping[:fields]["analyzed"] = {type: "string", index: "analyzed"}

              if mapping_options[:highlight].include?(field)
                field_mapping[:fields]["analyzed"][:term_vector] = "with_positions_offsets"
              end
            end

            mapping_options.except(:highlight, :searchable, :only_analyzed).each do |type, fields|
              if options[:match] == type || fields.include?(field)
                field_mapping[:fields][type] = {type: "string", index: "analyzed", analyzer: "searchkick_#{type}_index"}
              end
            end
          end

          mapping[field] = field_mapping
        end

        (options[:locations] || []).map(&:to_s).each do |field|
          mapping[field] = {
            type: "geo_point"
          }
        end

        (options[:unsearchable] || []).map(&:to_s).each do |field|
          mapping[field] = {
            type: "string",
            index: "no"
          }
        end

        routing = {}
        if options[:routing]
          routing = {required: true}
          unless options[:routing] == true
            routing[:path] = options[:routing].to_s
          end
        end

        dynamic_fields = {
          # analyzed field must be the default field for include_in_all
          # http://www.elasticsearch.org/guide/reference/mapping/multi-field-type/
          # however, we can include the not_analyzed field in _all
          # and the _all index analyzer will take care of it
          "{name}" => {type: "string", index: "not_analyzed", include_in_all: !options[:searchable]}
        }

        unless options[:searchable]
          if options[:match] && options[:match] != :word
            dynamic_fields[options[:match]] = {type: "string", index: "analyzed", analyzer: "searchkick_#{options[:match]}_index"}
          end

          if word
            dynamic_fields["analyzed"] = {type: "string", index: "analyzed"}
          end
        end

        mappings = {
          _default_: {
            properties: mapping,
            _routing: routing,
            # https://gist.github.com/kimchy/2898285
            dynamic_templates: [
              {
                string_template: {
                  match: "*",
                  match_mapping_type: "string",
                  mapping: {
                    # http://www.elasticsearch.org/guide/reference/mapping/multi-field-type/
                    type: "multi_field",
                    fields: dynamic_fields
                  }
                }
              }
            ]
          }
        }.deep_merge(options[:mappings] || {})
      end

      {
        settings: settings,
        mappings: mappings
      }
    end

    # other

    def tokens(text, options = {})
      client.indices.analyze({text: text, index: name}.merge(options))["tokens"].map { |t| t["token"] }
    end

    def klass_document_type(klass)
      if klass.respond_to?(:document_type)
        klass.document_type
      else
        klass.model_name.singular
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
      (options[:suggest] || []).map(&:to_s).each do |field|
        source[field] = nil unless source[field]
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
