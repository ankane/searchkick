require "searchkick/version"
require "searchkick/reindex"
require "searchkick/search"
require "searchkick/tasks"
require "tire"

module Searchkick
  module Model
    def searchkick(options = {})
      custom_settings = {
        analysis: {
          analyzer: {
            searchkick_keyword: {
              type: "custom",
              tokenizer: "keyword",
              filter: ["lowercase", "snowball"]
            },
            default_index: {
              type: "custom",
              tokenizer: "standard",
              # synonym should come last, after stemming and shingle
              # shingle must come before snowball
              filter: ["standard", "lowercase", "asciifolding", "stop", "snowball", "searchkick_index_shingle"]
            },
            searchkick_search: {
              type: "custom",
              tokenizer: "standard",
              filter: ["standard", "lowercase", "asciifolding", "stop", "snowball", "searchkick_search_shingle"]
            },
            searchkick_search2: {
              type: "custom",
              tokenizer: "standard",
              filter: ["standard", "lowercase", "asciifolding", "stop", "snowball"] #, "searchkick_search_shingle"]
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
            }
          }
        }
      }.merge(options[:settings] || {})
      synonyms = options[:synonyms] || []
      if synonyms.any?
        custom_settings[:analysis][:filter][:searchkick_synonym] = {
          type: "synonym",
          ignore_case: true,
          synonyms: synonyms
        }
        custom_settings[:analysis][:analyzer][:default_index][:filter] << "searchkick_synonym"
        custom_settings[:analysis][:analyzer][:searchkick_search][:filter].insert(-2, "searchkick_synonym")
        custom_settings[:analysis][:analyzer][:searchkick_search][:filter] << "searchkick_synonym"
        custom_settings[:analysis][:analyzer][:searchkick_search2][:filter] << "searchkick_synonym"
      end

      class_eval do
        extend Searchkick::Search
        extend Searchkick::Reindex
        include Tire::Model::Search
        include Tire::Model::Callbacks

        tire do
          settings custom_settings
          mapping do
            # indexes field, analyzer: "searchkick"
            if options[:conversions]
              indexes :conversions, type: "nested" do
                indexes :query, analyzer: "searchkick_keyword"
                indexes :count, type: "integer"
              end
            end
          end
        end
      end
    end
  end
end

require "active_record"
ActiveRecord::Base.send(:extend, Searchkick::Model) if defined?(ActiveRecord)
