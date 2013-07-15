require "searchkick/version"
require "searchkick/reindex"
require "searchkick/search"
require "searchkick/tasks"
require "tire"

module Searchkick
  # TODO fix this monstrosity
  # TODO add custom synonyms
  def self.settings(options = {})
    synonyms = options[:synonyms] || []
    settings = {
      analysis: {
        analyzer: {
          searchkick_keyword: {
            type: "custom",
            tokenizer: "keyword",
            filter: ["lowercase", "snowball"]
          },
          searchkick: {
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
    }
    if synonyms.any?
      settings[:analysis][:filter][:searchkick_synonym] = {
        type: "synonym",
        ignore_case: true,
        synonyms: synonyms
      }
      settings[:analysis][:analyzer][:searchkick][:filter] << "searchkick_synonym"
      settings[:analysis][:analyzer][:searchkick_search][:filter].insert(-2, "searchkick_synonym")
      settings[:analysis][:analyzer][:searchkick_search][:filter] << "searchkick_synonym"
      settings[:analysis][:analyzer][:searchkick_search2][:filter] << "searchkick_synonym"
    end
    settings
  end
end

Tire::Model::Search::ClassMethodsProxy.send :include, Searchkick::Reindex
Tire::Search::Search.send :include, Searchkick::Search
