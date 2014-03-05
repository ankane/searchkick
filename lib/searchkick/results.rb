module Searchkick
  class Results < Elasticsearch::Model::Response::Response
    attr_writer :response
    attr_accessor :current_page, :per_page

    delegate :each, :empty?, :size, :slice, :[], :to_ary, to: :records

    def suggestions
      if response["suggest"]
        response["suggest"].values.flat_map{|v| v.first["options"] }.sort_by{|o| -o["score"] }.map{|o| o["text"] }.uniq
      else
        raise "Pass `suggest: true` to the search method for suggestions"
      end
    end

    def with_details
      records.each_with_hit.map do |model, hit|
        details = {}
        if hit["highlight"]
          details[:highlight] = Hash[ hit["highlight"].map{|k, v| [k.sub(/\.analyzed\z/, "").to_sym, v.first] } ]
        end
        [model, details]
      end
    end

    def facets
      response["facets"]
    end

    def model_name
      klass.model_name
    end

    def total_count
      response["hits"]["total"]
    end

    def total_pages
      (total_count / per_page.to_f).ceil
    end

  end
end
