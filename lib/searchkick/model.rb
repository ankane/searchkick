module Searchkick
  module Model

    def searchkick(options = {})
      @searchkick_options = options.dup
      @searchkick_env = ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
      searchkick_env = @searchkick_env # for class_eval

      class_eval do
        extend Searchkick::Search
        extend Searchkick::Reindex
        include Searchkick::Similar
        include Tire::Model::Search
        include Tire::Model::Callbacks
        tire do
          index_name options[:index_name] || [klass.model_name.plural, searchkick_env].join("_")
        end

        def reindex
          update_index
        end

        def search_data
          to_hash.reject{|k, v| k == "id" }
        end

        def to_indexed_json
          source = search_data

          # stringify fields
          source = source.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo}

          options = self.class.instance_variable_get("@searchkick_options")

          # conversions
          conversions_field = options[:conversions]
          if conversions_field and source[conversions_field]
            source[conversions_field] = source[conversions_field].map{|k, v| {query: k, count: v} }
          end

          # hack to prevent generator field doesn't exist error
          (options[:suggest] || []).map(&:to_s).each do |field|
            source[field] = "a" if !source[field]
          end

          source.to_json
        end
      end
    end

  end
end
