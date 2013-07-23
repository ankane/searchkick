module Searchkick
  module Model

    def searchkick(options = {})
      @searchkick_options = options
      class_eval do
        extend Searchkick::Search
        extend Searchkick::Reindex
        include Tire::Model::Search
        include Tire::Model::Callbacks

        def reindex
          update_index
        end

        def to_indexed_json
          respond_to?(:search_data) ? search_data.to_json : super
        end
      end
    end

  end
end
