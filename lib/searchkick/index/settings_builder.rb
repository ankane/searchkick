module Searchkick
  class Index
    class SettingsBuilder
      attr_reader :options, :settings

      def initialize(options)
        @options = options
        @settings = initialized_settings
      end

      def output
        if Searchkick.env == "test"
          settings.merge!(number_of_shards: 1, number_of_replicas: 0)
        end
      end

      def initialized_settings
        {
          analysis: {
            analyzer: default_analyzers,
            filter: default_filters,
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
      end

      def default_analyzers
        {
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
        }
      end

      def default_filters
        {
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
        }
      end

      def set_similarity
        settings[:similarity] = { default: { type: options[:similarity] } }
      end

      def deep_merge_user_settings
        settings.deep_merge!(options[:settings] || {})
      end

      def set_synonyms
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

      def set_wordnet
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

      def delete_asciifolding_filter
        settings[:analysis][:analyzer].each do |_, analyzer_settings|
          analyzer_settings[:filter].reject! { |f| f == "asciifolding" }
        end
      end

      def synonyms
        @synonyms ||=
          if synonyms = options[:synonyms]
            language.respond_to?(:call) ? synonyms.call : synonyms
          else
            []
          end
      end

      def language
        @language ||=
          if lang = options[:language]
            language.respond_to?(:call) ? lang.call : lang
          end
      end
    end
  end
end

