require "forwardable"

module Searchkick
  class Results
    include Enumerable
    extend Forwardable

    attr_reader :klass, :response, :options

    def_delegators :results, :each, :any?, :empty?, :size, :length, :slice, :[], :to_ary

    def initialize(klass, response, options = {})
      @klass = klass
      @response = response
      @options = options
    end

    # experimental: may not make next release
    def records
      @records ||= results_query(klass, hits)
    end

    def results
      @results ||= begin
        if options[:load]
          # results can have different types
          results = {}

          hits.group_by { |hit, _| hit["_type"] }.each do |type, grouped_hits|
            results[type] = results_query(type.camelize.constantize, grouped_hits).to_a.index_by { |r| r.id.to_s }
          end

          # sort
          hits.map do |hit|
            results[hit["_type"]][hit["_id"].to_s]
          end.compact
        else
          hits.map do |hit|
            result =
              if hit["_source"]
                hit.except("_source").merge(hit["_source"])
              else
                hit.except("fields").merge(hit["fields"])
              end
            result["id"] ||= result["_id"] # needed for legacy reasons
            Hashie::Mash.new(result)
          end
        end
      end
    end

    def suggestions
      if response["suggest"]
        response["suggest"].values.flat_map { |v| v.first["options"] }.sort_by { |o| -o["score"] }.map { |o| o["text"] }.uniq
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
          details[:highlight] = Hash[hit["highlight"].map { |k, v| [(options[:json] ? k : k.sub(/\.analyzed\z/, "")).to_sym, v.first] }]
        end
        [model, details]
      end
    end

    def facets
      response["facets"]
    end

    def aggs
      @aggs ||= begin
        response["aggregations"].dup.each do |field, filtered_agg|
          buckets = filtered_agg[field]
          # move the buckets one level above into the field hash
          if buckets
            filtered_agg.delete(field)
            filtered_agg.merge!(buckets)
          end
        end
      end
    end

    def took
      response["took"]
    end

    def model_name
      klass.model_name
    end

    def entry_name
      model_name.human.downcase
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

    def padding
      options[:padding]
    end

    def total_pages
      (total_count / per_page.to_f).ceil
    end
    alias_method :num_pages, :total_pages

    def offset_value
      (current_page - 1) * per_page + padding
    end
    alias_method :offset, :offset_value

    def previous_page
      current_page > 1 ? (current_page - 1) : nil
    end
    alias_method :prev_page, :previous_page

    def next_page
      current_page < total_pages ? (current_page + 1) : nil
    end

    def first_page?
      previous_page.nil?
    end

    def last_page?
      next_page.nil?
    end

    def out_of_range?
      current_page > total_pages
    end

    def hits
      @response["hits"]["hits"]
    end

    private

    def results_query(records, hits)
      ids = hits.map { |hit| hit["_id"] }

      if options[:includes]
        records =
          if defined?(NoBrainer::Document) && records < NoBrainer::Document
            records.preload(options[:includes])
          else
            records.includes(options[:includes])
          end
      end

      if records.respond_to?(:primary_key) && records.primary_key
        # ActiveRecord
        records.where(records.primary_key => ids)
      elsif records.respond_to?(:all) && records.all.respond_to?(:for_ids)
        # Mongoid 2
        records.all.for_ids(ids)
      elsif records.respond_to?(:queryable)
        # Mongoid 3+
        records.queryable.for_ids(ids)
      elsif records.respond_to?(:unscoped) && records.all.respond_to?(:preload)
        # Nobrainer
        records.unscoped.where(:id.in => ids)
      else
        raise "Not sure how to load records"
      end
    end
  end
end
