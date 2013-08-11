module Searchkick
  module Reindex

    # https://gist.github.com/jarosan/3124884
    def reindex
      alias_name = tire.index.name
      new_index = alias_name + "_" + Time.now.strftime("%Y%m%d%H%M%S")
      index = Tire::Index.new(new_index)

      success = index.create searchkick_index_options
      raise index.response.to_s if !success

      # use scope for import
      scope = respond_to?(:search_import) ? search_import : self
      scope.find_in_batches do |batch|
        index.import batch
      end

      if a = Tire::Alias.find(alias_name)
        old_indices = a.indices.dup
        old_indices.each do |index|
          a.indices.delete index
        end

        a.indices.add new_index
        response = a.save

        if response.success?
          old_indices.each do |index|
            i = Tire::Index.new(index)
            i.delete
          end
        end
      else
        tire.index.delete if tire.index.exists?
        response = Tire::Alias.create(name: alias_name, indices: [new_index])
      end

      response.success? || (raise response.to_s)
    end

    private

    def searchkick_index_options
      options = @searchkick_options

      settings = {
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
              filter: ["standard", "lowercase", "asciifolding", "stop", "searchkick_index_shingle", "snowball"]
            },
            searchkick_search: {
              type: "custom",
              tokenizer: "standard",
              filter: ["standard", "lowercase", "asciifolding", "stop", "searchkick_search_shingle", "snowball"]
            },
            searchkick_search2: {
              type: "custom",
              tokenizer: "standard",
              filter: ["standard", "lowercase", "asciifolding", "stop", "snowball"]
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
            searchkick_suggest_index: {
              type: "custom",
              tokenizer: "standard",
              filter: ["lowercase", "asciifolding", "searchkick_suggest_shingle"]
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
      }.merge(options[:settings] || {})

      # synonyms
      synonyms = options[:synonyms] || []
      if synonyms.any?
        settings[:analysis][:filter][:searchkick_synonym] = {
          type: "synonym",
          synonyms: synonyms.select{|s| s.size > 1 }.map{|s| s.join(",") }
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
      end

      mapping = {}

      # conversions
      if options[:conversions]
        mapping[:conversions] = {
          type: "nested",
          properties: {
            query: {type: "string", analyzer: "searchkick_keyword"},
            count: {type: "integer"}
          }
        }
      end

      # autocomplete and suggest
      autocomplete = (options[:autocomplete] || []).map(&:to_s)
      suggest = (options[:suggest] || []).map(&:to_s)
      (autocomplete + suggest).uniq.each do |field|
        field_mapping = {
          type: "multi_field",
          fields: {
            field => {type: "string", index: "not_analyzed"},
            "analyzed" => {type: "string", index: "analyzed"}
          }
        }
        if autocomplete.include?(field)
          field_mapping[:fields]["autocomplete"] = {type: "string", index: "analyzed", analyzer: "searchkick_autocomplete_index"}
        end
        if suggest.include?(field)
          field_mapping[:fields]["suggest"] = {type: "string", index: "analyzed", analyzer: "searchkick_suggest_index"}
        end
        mapping[field] = field_mapping
      end

      mappings = {
        document_type.to_sym => {
          properties: mapping,
          # https://gist.github.com/kimchy/2898285
          dynamic_templates: [
            {
              string_template: {
                match: "*",
                match_mapping_type: "string",
                mapping: {
                  # http://www.elasticsearch.org/guide/reference/mapping/multi-field-type/
                  type: "multi_field",
                  fields: {
                    # analyzed field must be the default field for include_in_all
                    # http://www.elasticsearch.org/guide/reference/mapping/multi-field-type/
                    # however, we can include the not_analyzed field in _all
                    # and the _all index analyzer will take care of it
                    "{name}" => {type: "string", index: "not_analyzed"},
                    "analyzed" => {type: "string", index: "analyzed"}
                  }
                }
              }
            }
          ]
        }
      }

      {
        settings: settings,
        mappings: mappings
      }
    end

  end
end
