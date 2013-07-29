module Searchkick
  module Model

    def searchkick(options = {})
      @searchkick_options = options.dup
      @searchkick_options[:conversions] = true if options[:conversions].nil?

      class_eval do
        extend Searchkick::Search
        extend Searchkick::Reindex
        include Tire::Model::Search
        include Tire::Model::Callbacks
        tire do
          index_name options[:index_name] || [klass.model_name.plural, ENV["RACK_ENV"] || "development"].join("_")
        end

        def reindex
          update_index
        end

        def search_data
          as_json
        end

        def to_indexed_json
          source = search_data
          if self.class.instance_variable_get("@searchkick_options")[:conversions] and source[:conversions]
            source[:conversions] = source[:conversions].map{|k, v| {query: k, count: v} }
          end
          source.to_json
        end
      end
    end

  end
end
