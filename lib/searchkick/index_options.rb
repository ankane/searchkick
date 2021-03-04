module Searchkick
  class IndexOptions
    attr_reader :options

    def initialize(index)
      @options = index.options
    end

    def index_options
      custom_mapping = options[:mappings] || {}
      if below70? && custom_mapping.keys.map(&:to_sym).include?(:properties)
        # add type
        custom_mapping = {index_type => custom_mapping}
      end

      if options[:mappings] && !options[:merge_mappings]
        settings = options[:settings] || {}
        mappings = custom_mapping
      else
        settings = generate_settings
        mappings = generate_mappings.symbolize_keys.deep_merge(custom_mapping.symbolize_keys)
      end

      set_deep_paging(settings) if options[:deep_paging]

      {
        settings: settings,
        mappings: mappings
      }
    end

    def generate_settings
      language = options[:language]
      language = language.call if language.respond_to?(:call)

      settings = {
        analysis: {
          analyzer: {
            searchkick_keyword: {
              type: "custom",
              tokenizer: "keyword",
              filter: ["lowercase"] + (options[:stem_conversions] ? ["searchkick_stemmer"] : [])
            },
            default_analyzer => {
              type: "custom",
              # character filters -> tokenizer -> token filters
              # https://www.elastic.co/guide/en/elasticsearch/guide/current/analysis-intro.html
              char_filter: ["ampersand"],
              tokenizer: "standard",
              # synonym should come last, after stemming and shingle
              # shingle must come before searchkick_stemmer
              filter: ["lowercase", "asciifolding", "searchkick_search_shingle", "searchkick_stemmer", "gist_special_chars"]
            },
            searchkick_search: {
              type: "custom",
              char_filter: ["ampersand"],
              tokenizer: "standard",
              filter: ["lowercase", "asciifolding", "searchkick_search_shingle", "searchkick_stemmer", "gist_special_chars"]
            },
            searchkick_search2: {
              type: "custom",
              char_filter: ["ampersand"],
              tokenizer: "standard",
              filter: ["lowercase", "asciifolding", "searchkick_search_shingle", "searchkick_stemmer", "gist_special_chars"]
            },
            # https://github.com/leschenko/elasticsearch_autocomplete/blob/master/lib/elasticsearch_autocomplete/analyzers.rb
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
            # lucky find https://web.archiveorange.com/archive/v/AAfXfQ17f57FcRINsof7
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
              type: "edge_ngram",
              min_gram: 1,
              max_gram: 50
            },
            searchkick_ngram: {
              type: "ngram",
              min_gram: 1,
              max_gram: 50
            },
            gist_special_chars: {
              "type": "ngram",
              "min_gram": 2,
              "max_gram": 30,
              "token_chars": ["letter","digit","symbol","punctuation"]
            },
            searchkick_stemmer: {
              # use stemmer if language is lowercase, snowball otherwise
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
          }
        }
      }

      raise ArgumentError, "Can't pass both language and stemmer" if options[:stemmer] && language
      update_language(settings, language)
      update_stemming(settings)

      if Searchkick.env == "test"
        settings[:number_of_shards] = 1
        settings[:number_of_replicas] = 0
      end

      # TODO remove in Searchkick 5 (classic no longer supported)
      if options[:similarity]
        settings[:similarity] = {default: {type: options[:similarity]}}
      end

      unless below62?
        settings[:index] = {
          max_ngram_diff: 49,
          max_shingle_diff: 4
        }
      end

      if options[:case_sensitive]
        settings[:analysis][:analyzer].each do |_, analyzer|
          analyzer[:filter].delete("lowercase")
        end
      end

      # TODO do this last in Searchkick 5
      settings = settings.symbolize_keys.deep_merge((options[:settings] || {}).symbolize_keys)

      add_synonyms(settings)
      add_search_synonyms(settings)
      # TODO remove in Searchkick 5
      add_wordnet(settings) if options[:wordnet]

      if options[:special_characters] == false
        settings[:analysis][:analyzer].each_value do |analyzer_settings|
          analyzer_settings[:filter].reject! { |f| f == "asciifolding" }
        end
      end

      settings
    end

    def update_language(settings, language)
      case language
      when "chinese"
        settings[:analysis][:analyzer].merge!(
          default_analyzer => {
            type: "ik_smart"
          },
          searchkick_search: {
            type: "ik_smart"
          },
          searchkick_search2: {
            type: "ik_max_word"
          }
        )
      when "chinese2", "smartcn"
        settings[:analysis][:analyzer].merge!(
          default_analyzer => {
            type: "smartcn"
          },
          searchkick_search: {
            type: "smartcn"
          },
          searchkick_search2: {
            type: "smartcn"
          }
        )
      when "japanese"
        settings[:analysis][:analyzer].merge!(
          default_analyzer => {
            type: "kuromoji"
          },
          searchkick_search: {
            type: "kuromoji"
          },
          searchkick_search2: {
            type: "kuromoji"
          }
        )
      when "korean"
        settings[:analysis][:analyzer].merge!(
          default_analyzer => {
            type: "openkoreantext-analyzer"
          },
          searchkick_search: {
            type: "openkoreantext-analyzer"
          },
          searchkick_search2: {
            type: "openkoreantext-analyzer"
          }
        )
      when "korean2"
        settings[:analysis][:analyzer].merge!(
          default_analyzer => {
            type: "nori"
          },
          searchkick_search: {
            type: "nori"
          },
          searchkick_search2: {
            type: "nori"
          }
        )
      when "vietnamese"
        settings[:analysis][:analyzer].merge!(
          default_analyzer => {
            type: "vi_analyzer"
          },
          searchkick_search: {
            type: "vi_analyzer"
          },
          searchkick_search2: {
            type: "vi_analyzer"
          }
        )
      when "polish", "ukrainian"
        settings[:analysis][:analyzer].merge!(
          default_analyzer => {
            type: language
          },
          searchkick_search: {
            type: language
          },
          searchkick_search2: {
            type: language
          }
        )
      end
    end

    def update_stemming(settings)
      if options[:stemmer]
        stemmer = options[:stemmer]
        # could also support snowball and stemmer
        case stemmer[:type]
        when "hunspell"
          # supports all token filter options
          settings[:analysis][:filter][:searchkick_stemmer] = stemmer
        else
          raise ArgumentError, "Unknown stemmer: #{stemmer[:type]}"
        end
      end

      stem = options[:stem]

      # language analyzer used
      stem = false if settings[:analysis][:analyzer][default_analyzer][:type] != "custom"

      if stem == false
        settings[:analysis][:filter].delete(:searchkick_stemmer)
        settings[:analysis][:analyzer].each do |_, analyzer|
          analyzer[:filter].delete("searchkick_stemmer") if analyzer[:filter]
        end
      end

      if options[:stemmer_override]
        stemmer_override = {
          type: "stemmer_override"
        }
        if options[:stemmer_override].is_a?(String)
          stemmer_override[:rules_path] = options[:stemmer_override]
        else
          stemmer_override[:rules] = options[:stemmer_override]
        end
        settings[:analysis][:filter][:searchkick_stemmer_override] = stemmer_override

        settings[:analysis][:analyzer].each do |_, analyzer|
          stemmer_index = analyzer[:filter].index("searchkick_stemmer") if analyzer[:filter]
          analyzer[:filter].insert(stemmer_index, "searchkick_stemmer_override") if stemmer_index
        end
      end

      if options[:stem_exclusion]
        settings[:analysis][:filter][:searchkick_stem_exclusion] = {
          type: "keyword_marker",
          keywords: options[:stem_exclusion]
        }

        settings[:analysis][:analyzer].each do |_, analyzer|
          stemmer_index = analyzer[:filter].index("searchkick_stemmer") if analyzer[:filter]
          analyzer[:filter].insert(stemmer_index, "searchkick_stem_exclusion") if stemmer_index
        end
      end
    end

    def generate_mappings
      mapping = {}

      keyword_mapping = {type: "keyword"}
      keyword_mapping[:ignore_above] = options[:ignore_above] || 30000

      # conversions
      Array(options[:conversions]).each do |conversions_field|
        mapping[conversions_field] = {
          type: "nested",
          properties: {
            query: {type: default_type, analyzer: "searchkick_keyword"},
            count: {type: "integer"}
          }
        }
      end

      mapping_options = Hash[
        [:suggest, :word, :text_start, :text_middle, :text_end, :word_start, :word_middle, :word_end, :highlight, :searchable, :filterable]
          .map { |type| [type, (options[type] || []).map(&:to_s)] }
      ]

      word = options[:word] != false && (!options[:match] || options[:match] == :word)

      mapping_options[:searchable].delete("_all")

      analyzed_field_options = {type: default_type, index: true, analyzer: default_analyzer}

      mapping_options.values.flatten.uniq.each do |field|
        fields = {}

        if options.key?(:filterable) && !mapping_options[:filterable].include?(field)
          fields[field] = {type: default_type, index: false}
        else
          fields[field] = keyword_mapping
        end

        if !options[:searchable] || mapping_options[:searchable].include?(field)
          if word
            fields[:analyzed] = analyzed_field_options

            if mapping_options[:highlight].include?(field)
              fields[:analyzed][:term_vector] = "with_positions_offsets"
            end
          end

          mapping_options.except(:highlight, :searchable, :filterable, :word).each do |type, f|
            if options[:match] == type || f.include?(field)
              fields[type] = {type: default_type, index: true, analyzer: "searchkick_#{type}_index"}
            end
          end
        end

        mapping[field] = fields[field].merge(fields: fields.except(field))
      end

      (options[:locations] || []).map(&:to_s).each do |field|
        mapping[field] = {
          type: "geo_point"
        }
      end

      options[:geo_shape] = options[:geo_shape].product([{}]).to_h if options[:geo_shape].is_a?(Array)
      (options[:geo_shape] || {}).each do |field, shape_options|
        mapping[field] = shape_options.merge(type: "geo_shape")
      end

      if options[:inheritance]
        mapping[:type] = keyword_mapping
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
        "{name}" => keyword_mapping
      }

      if options.key?(:filterable)
        dynamic_fields["{name}"] = {type: default_type, index: false}
      end

      unless options[:searchable]
        if options[:match] && options[:match] != :word
          dynamic_fields[options[:match]] = {type: default_type, index: true, analyzer: "searchkick_#{options[:match]}_index"}
        end

        if word
          dynamic_fields[:analyzed] = analyzed_field_options
        end
      end

      # http://www.elasticsearch.org/guide/reference/mapping/multi-field-type/
      multi_field = dynamic_fields["{name}"].merge(fields: dynamic_fields.except("{name}"))

      mappings = {
        properties: mapping,
        _routing: routing,
        # https://gist.github.com/kimchy/2898285
        dynamic_templates: [
          {
            string_template: {
              match: "*",
              match_mapping_type: "string",
              mapping: multi_field
            }
          }
        ]
      }

      if below70?
        mappings = {index_type => mappings}
      end

      mappings
    end

    def add_synonyms(settings)
      synonyms = options[:synonyms] || []
      synonyms = synonyms.call if synonyms.respond_to?(:call)
      if synonyms.any?
        settings[:analysis][:filter][:searchkick_synonym] = {
          type: "synonym",
          # only remove a single space from synonyms so three-word synonyms will fail noisily instead of silently
          synonyms: synonyms.select { |s| s.size > 1 }.map { |s| s.is_a?(Array) ? s.map { |s2| s2.sub(/\s+/, "") }.join(",") : s }.map(&:downcase)
        }
        # choosing a place for the synonym filter when stemming is not easy
        # https://groups.google.com/forum/#!topic/elasticsearch/p7qcQlgHdB8
        # TODO use a snowball stemmer on synonyms when creating the token filter

        # http://elasticsearch-users.115913.n3.nabble.com/synonym-multi-words-search-td4030811.html
        # I find the following approach effective if you are doing multi-word synonyms (synonym phrases):
        # - Only apply the synonym expansion at index time
        # - Don't have the synonym filter applied search
        # - Use directional synonyms where appropriate. You want to make sure that you're not injecting terms that are too general.
        settings[:analysis][:analyzer][default_analyzer][:filter].insert(2, "searchkick_synonym")

        %w(word_start word_middle word_end).each do |type|
          settings[:analysis][:analyzer]["searchkick_#{type}_index".to_sym][:filter].insert(2, "searchkick_synonym")
        end
      end
    end

    def add_search_synonyms(settings)
      search_synonyms = options[:search_synonyms] || []
      search_synonyms = search_synonyms.call if search_synonyms.respond_to?(:call)
      if search_synonyms.is_a?(String) || search_synonyms.any?
        if search_synonyms.is_a?(String)
          synonym_graph = {
            type: "synonym_graph",
            synonyms_path: search_synonyms
          }
          synonym_graph[:updateable] = true unless below73?
        else
          synonym_graph = {
            type: "synonym_graph",
            # TODO confirm this is correct
            synonyms: search_synonyms.select { |s| s.size > 1 }.map { |s| s.is_a?(Array) ? s.join(",") : s }.map(&:downcase)
          }
        end
        settings[:analysis][:filter][:searchkick_synonym_graph] = synonym_graph

        [:searchkick_search2, :searchkick_word_search].each do |analyzer|
          settings[:analysis][:analyzer][analyzer][:filter].insert(2, "searchkick_synonym_graph")
        end
      end
    end

    def add_wordnet(settings)
      settings[:analysis][:filter][:searchkick_wordnet] = {
        type: "synonym",
        format: "wordnet",
        synonyms_path: Searchkick.wordnet_path
      }

      settings[:analysis][:analyzer][default_analyzer][:filter].insert(4, "searchkick_wordnet")
      settings[:analysis][:analyzer][default_analyzer][:filter] << "searchkick_wordnet"

      %w(word_start word_middle word_end).each do |type|
        settings[:analysis][:analyzer]["searchkick_#{type}_index".to_sym][:filter].insert(2, "searchkick_wordnet")
      end
    end

    def set_deep_paging(settings)
      if !settings.dig(:index, :max_result_window) && !settings[:"index.max_result_window"]
        settings[:index] ||= {}
        settings[:index][:max_result_window] = 1_000_000_000
      end
    end

    def index_type
      @index_type ||= begin
        index_type = options[:_type]
        index_type = index_type.call if index_type.respond_to?(:call)
        index_type
      end
    end

    def default_type
      "text"
    end

    def default_analyzer
      :searchkick_index
    end

    def below62?
      Searchkick.server_below?("6.2.0")
    end

    def below70?
      Searchkick.server_below?("7.0.0")
    end

    def below73?
      Searchkick.server_below?("7.3.0")
    end
  end
end
