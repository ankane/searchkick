module Searchkick
  module Search

    def search(term = nil, options = {})
      query = Searchkick::Query.new(self, term, options)
      if options[:execute] == false
        query
      else
        query.execute
      end
    end

  end
end
