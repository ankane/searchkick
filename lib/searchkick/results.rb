module Searchkick
  class Results
    include Enumerable
    extend Forwardable

    attr_reader :klass, :response, :options

    def_delegators :results, :each, :empty?, :size, :slice, :[], :to_ary

    def initialize(klass, response, options = {})
      @klass = klass
      @response = response
      @options = options
    end

    def results
      @results ||= begin
        if options[:load]
          hit_ids = hits.map{|hit| hit["_id"] }
          records = klass
          if options[:includes]
            records = records.includes(options[:includes])
          end
          records = records.find(hit_ids)
          hit_ids = hit_ids.map(&:to_s)
          records.sort_by{|r| hit_ids.index(r.id.to_s)  }
        else
          hits.map{|hit| Hashie::Mash.new(hit["_source"]) }
        end
      end
    end

    def suggestions
      if response["suggest"]
        response["suggest"].values.flat_map{|v| v.first["options"] }.sort_by{|o| -o["score"] }.map{|o| o["text"] }.uniq
      else
        raise "Pass `suggest: true` to the search method for suggestions"
      end
    end

    def each_with_hit(&block)
      results.zip(hits).each(&block)
    end

    def with_details
      each_with_hit.map do |model, hit|
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
    alias_method :total_entries, :total_count

    def current_page
      options[:page]
    end

    def per_page
      options[:per_page]
    end
    alias_method :limit_value, :per_page

    def total_pages
      (total_count / per_page.to_f).ceil
    end

    def offset_value
      current_page * per_page
    end

    def previous_page
      current_page > 1 ? (current_page - 1) : nil
    end

    def next_page
      current_page < total_pages ? (current_page + 1) : nil
    end

    # First page of the collection ?
    def first_page?
      current_page == 1
    end

    # Last page of the collection?
    def last_page?
      current_page >= total_pages
    end

    protected

    def hits
      @response["hits"]["hits"]
    end

  end
end
