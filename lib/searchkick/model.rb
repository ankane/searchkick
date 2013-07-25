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

        # alias_method_chain style
        alias_method :to_indexed_json_without_searchkick, :to_indexed_json

        def to_indexed_json
          respond_to?(:_source) ? _source.to_json : to_indexed_json_without_searchkick
        end
      end
    end

  end
end
