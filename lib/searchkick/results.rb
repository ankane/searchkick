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

    def results
      @results ||= with_hit.map(&:first)
    end

    def with_hit
      @with_hit ||= begin
        if options[:load]
          # results can have different types
          results = {}

          hits.group_by { |hit, _| hit["_type"] }.each do |type, grouped_hits|
            klass = (!options[:index_name] && @klass) || type.camelize.constantize
            results[type] = results_query(klass, grouped_hits).to_a.index_by { |r| r.id.to_s }
          end

          missing_ids = []

          # sort
          results =
            hits.map do |hit|
              result = results[hit["_type"]][hit["_id"].to_s]
              if result && !(options[:load].is_a?(Hash) && options[:load][:dumpable])
                if (hit["highlight"] || options[:highlight]) && !result.respond_to?(:search_highlights)
                  highlights = hit_highlights(hit)
                  result.define_singleton_method(:search_highlights) do
                    highlights
                  end
                end
              end
              [result, hit]
            end.select do |result, hit|
              missing_ids << hit["_id"] unless result
              result
            end

          if missing_ids.any?
            warn "[searchkick] WARNING: Records in search index do not exist in database: #{missing_ids.join(", ")}"
          end

          results
        else
          hits.map do |hit|
            result =
              if hit["_source"]
                hit.except("_source").merge(hit["_source"])
              elsif hit["fields"]
                hit.except("fields").merge(hit["fields"])
              else
                hit
              end

            if hit["highlight"] || options[:highlight]
              highlight = Hash[hit["highlight"].to_a.map { |k, v| [base_field(k), v.first] }]
              options[:highlighted_fields].map { |k| base_field(k) }.each do |k|
                result["highlighted_#{k}"] ||= (highlight[k] || result[k])
              end
            end

            result["id"] ||= result["_id"] # needed for legacy reasons
            [HashWrapper.new(result), hit]
          end
        end
      end
    end

    def suggestions
      if response["suggest"]
        response["suggest"].values.flat_map { |v| v.first["options"] }.sort_by { |o| -o["score"] }.map { |o| o["text"] }.uniq
      elsif options[:term] == "*"
        []
      else
        raise "Pass `suggest: true` to the search method for suggestions"
      end
    end

    def aggregations
      response["aggregations"]
    end

    def aggs
      @aggs ||= begin
        if aggregations
          aggregations.dup.each do |field, filtered_agg|
            buckets = filtered_agg[field]
            # move the buckets one level above into the field hash
            if buckets
              filtered_agg.delete(field)
              filtered_agg.merge!(buckets)
            end
          end
        end
      end
    end

    def took
      response["took"]
    end

    def error
      response["error"]
    end

    def model_name
      klass.model_name
    end

    def entry_name(options = {})
      if options.empty?
        # backward compatibility
        model_name.human.downcase
      else
        default = options[:count] == 1 ? model_name.human : model_name.human.pluralize
        model_name.human(options.reverse_merge(default: default))
      end
    end

    def total_count
      options[:total_entries] || response["hits"]["total"]
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
      if error
        raise Searchkick::Error, "Query error - use the error method to view it"
      else
        @response["hits"]["hits"]
      end
    end

    def highlights(multiple: false)
      hits.map do |hit|
        hit_highlights(hit, multiple: multiple)
      end
    end

    def with_highlights(multiple: false)
      with_hit.map do |result, hit|
        [result, hit_highlights(hit, multiple: multiple)]
      end
    end

    def misspellings?
      @options[:misspellings]
    end

    private

    def results_query(records, hits)
      ids = hits.map { |hit| hit["_id"] }
      if options[:includes] || options[:model_includes]
        included_relations = []
        combine_includes(included_relations, options[:includes])
        combine_includes(included_relations, options[:model_includes][records]) if options[:model_includes]

        records =
          if defined?(NoBrainer::Document) && records < NoBrainer::Document
            if Gem.loaded_specs["nobrainer"].version >= Gem::Version.new("0.21")
              records.eager_load(included_relations)
            else
              records.preload(included_relations)
            end
          else
            records.includes(included_relations)
          end
      end

      if options[:scope_results]
        records = options[:scope_results].call(records)
      end

      Searchkick.load_records(records, ids)
    end

    def combine_includes(result, inc)
      if inc
        if inc.is_a?(Array)
          result.concat(inc)
        else
          result << inc
        end
      end
    end

    def base_field(k)
      k.sub(/\.(analyzed|word_start|word_middle|word_end|text_start|text_middle|text_end|exact)\z/, "")
    end

    def hit_highlights(hit, multiple: false)
      if hit["highlight"]
        Hash[hit["highlight"].map { |k, v| [(options[:json] ? k : k.sub(/\.#{@options[:match_suffix]}\z/, "")).to_sym, multiple ? v : v.first] }]
      else
        {}
      end
    end
  end
end
