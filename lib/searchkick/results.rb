module Searchkick
  class Results < Tire::Results::Collection

    # TODO use all fields
    # return nil suggestion if term does not change
    def suggestion
      if @response["suggest"]
        @response["suggest"].values.first.first["options"].first["text"] rescue nil
      else
        raise "Pass `suggest: true` to the search method for suggestions"
      end
    end

  end
end
