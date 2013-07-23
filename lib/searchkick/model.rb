module Searchkick
  module Model

    def searchkick(options = {})
      @searchkick_options = options
      class_eval do
        extend Searchkick::Search
        extend Searchkick::Reindex
        include Tire::Model::Search
        include Tire::Model::Callbacks
      end
    end

  end
end
