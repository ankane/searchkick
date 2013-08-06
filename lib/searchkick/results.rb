module Searchkick
  class Results < Tire::Results::Collection

    # TODO use all fields
    # return nil suggestion if term does not change
    def suggestion
      if @response["suggest"]
        original_term = options[:term].downcase
        suggestion = original_term.dup
        @response["suggest"].values.first.each do |s|
          first_option = s["options"].first
          if first_option
            suggestion.sub!(s["text"], first_option["text"])
          end
        end
        suggestion == original_term ? nil : suggestion
      else
        raise "Pass `suggest: true` to the search method for suggestions"
      end
    end

  end
end
