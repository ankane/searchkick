require "searchkick/version"
require "searchkick/tasks"
require "tire"

module Searchkick
  module ClassMethods

    # https://gist.github.com/jarosan/3124884
    def reindex
      alias_name = klass.tire.index.name
      new_index = alias_name + "_" + Time.now.strftime("%Y%m%d%H%M%S")

      # Rake::Task["tire:import"].invoke
      index = Tire::Index.new(new_index)
      Tire::Tasks::Import.create_index(index, klass)
      scope = klass.respond_to?(:tire_import) ? klass.tire_import : klass
      scope.find_in_batches do |batch|
        index.import batch
      end

      if a = Tire::Alias.find(alias_name)
        puts "[IMPORT] Alias found: #{Tire::Alias.find(alias_name).indices.to_ary.join(",")}"
        old_indices = Tire::Alias.find(alias_name).indices
        old_indices.each do |index|
          a.indices.delete index
        end

        a.indices.add new_index
        a.save

        old_indices.each do |index|
          puts "[IMPORT] Deleting index: #{index}"
          i = Tire::Index.new(index)
          i.delete if i.exists?
        end
      else
        puts "[IMPORT] No alias found. Deleting index, creating new one, and setting up alias"
        i = Tire::Index.new(alias_name)
        i.delete if i.exists?
        Tire::Alias.create(name: alias_name, indices: [new_index])
      end

      puts "[IMPORT] Saved alias #{alias_name} pointing to #{new_index}"
    end

  end

  module SearchMethods
    def searchkick_query(fields, term)
      query do
        boolean do
          should do
            match fields, term, boost: 10, operator: "and", analyzer: "searchkick2"
          end
          should do
            match fields, term, use_dis_max: false, fuzziness: 0.6, max_expansions: 4, prefix_length: 2, operator: "and", analyzer: "searchkick2"
          end
          should do
            nested path: "conversions", score_mode: "total" do
              query do
                custom_score script: "log(doc['count'].value)" do
                  match "query", term
                end
              end
            end
          end
        end
      end
    end
  end

  # TODO fix this monstrosity
  # TODO add custom synonyms
  def self.settings
    {
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
            filter: ["standard", "lowercase", "asciifolding", "stop", "searchkick_shingle", "snowball", "searchkick_synonym"]
            # filter: ["standard", "lowercase", "asciifolding", "stop", "snowball"]
          },
          # lucky find http://web.archiveorange.com/archive/v/AAfXfQ17f57FcRINsof7
          searchkick2: {
            type: "custom",
            tokenizer: "standard",
            # synonym should come last, after stemming and shingle
            # shingle must come before snowball
            # filter: ["standard", "lowercase", "asciifolding", "stop", "searchkick_shingle", "snowball", "searchkick_synonym"]
            filter: ["standard", "lowercase", "asciifolding", "stop", "searchkick_shingle2", "snowball", "searchkick_synonym"]
          }
        },
        filter: {
          searchkick_shingle: {
            type: "shingle",
            token_separator: ""
          },
          searchkick_shingle2: {
            type: "shingle",
            token_separator: "",
            output_unigrams: false,
            output_unigrams_if_no_shingles: true
          },
          searchkick_synonym: {
            type: "synonym",
            ignore_case: true,
            # tokenizer: "keyword",
            synonyms: [
              "clorox => bleach",
              "saran wrap => plastic wrap",
              "scallion => green onion",
              "qtip => cotton swab"
            ]
          }
        }
      }
    }
  end

end

Tire::Model::Search::ClassMethodsProxy.send :include, Searchkick::ClassMethods
Tire::Search::Search.send :include, Searchkick::SearchMethods
