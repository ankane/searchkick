module Searchkick
  module Search

    def search(term, options = {})
      Searchkick::Query.new(self, term, options).results
    end

  end
end
