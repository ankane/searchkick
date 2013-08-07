module Searchkick
  class Results < Tire::Results::Collection

    # TODO use all fields
    # return nil suggestion if term does not change
    def suggestions
      if @response["suggest"]
        @response["suggest"].values.flat_map{|v| v.first["options"] }.sort_by{|o| -o["score"] }.map{|o| o["text"] }.uniq
      else
        raise "Pass `suggest: true` to the search method for suggestions"
      end
    end

  end
end
