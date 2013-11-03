module Searchkick
  module Model

    def searchkick(options = {})
      class_eval do
        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_env, ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
        class_variable_set :@@searchkick_klass, self
        cattr_reader :searchkick_options, :searchkick_env, :searchkick_klass

        extend Searchkick::Search
        extend Searchkick::Reindex
        include Searchkick::Similar
        include Tire::Model::Search

        index_name = options[:index_name] || [options[:index_prefix], model_name.plural, searchkick_env].compact.join("_")

        tire.index_name index_name
        descendants.each do |subclass|
          subclass.tire.index_name index_name
        end

        def reindex
          tire.update_index
        end

        unless options[:callbacks] == false
          # TODO ability to temporarily disable
          after_save :reindex
          after_destroy :reindex
        end

        def search_data
          to_hash.reject{|k, v| k == "id" }
        end

        def to_indexed_json
          source = search_data

          # stringify fields
          source = source.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo}

          options = self.class.searchkick_options

          # conversions
          conversions_field = options[:conversions]
          if conversions_field and source[conversions_field]
            source[conversions_field] = source[conversions_field].map{|k, v| {query: k, count: v} }
          end

          # hack to prevent generator field doesn't exist error
          (options[:suggest] || []).map(&:to_s).each do |field|
            source[field] = "a" if !source[field]
          end

          # locations
          (options[:locations] || []).map(&:to_s).each do |field|
            source[field] = source[field].reverse if source[field]
          end

          source.to_json
        end
      end
    end

  end
end
