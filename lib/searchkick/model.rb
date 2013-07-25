module Searchkick
  module Model

    def searchkick(options = {})
      @searchkick_options = options
      class_eval do
        extend Searchkick::Search
        extend Searchkick::Reindex
        include Tire::Model::Search
        include Tire::Model::Callbacks
        attr_accessor :_score

        def reindex
          update_index
        end

        def _source
          as_json
        end

        def to_indexed_json
          source = _source
          if self.class.instance_variable_get("@searchkick_options")[:conversions] and source[:conversions]
            source[:conversions] = source[:conversions].map{|k, v| {query: k, count: v} }
          end
          source.to_json
        end
      end
    end

  end
end
