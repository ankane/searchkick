module Searchkick
  class Query
    attr_reader :klass, :term, :options

    def initialize(klass, term, options = {})
      if term.is_a?(Hash)
        options = term
        term = nil
      else
        term = term.to_s
      end

      @klass = klass
      @term = term
      @options = options

      @facet_limits = {}
    end

    def searchkick_options
      klass.searchkick_options
    end

    def searchkick_index
      klass.searchkick_index
    end

    def searchkick_klass
      klass.searchkick_klass
    end

    def document_type
      klass.document_type
    end

    # construct the payload from the provided options
    def payload
      return @payload if defined?(@payload)

      @payload = {
        query: query,
        size: per_page,
        from: offset
      }

      apply_custom_filters(payload) if custom_filters?
      apply_explain(payload) if explain?
      apply_order(payload) if order?
      apply_where_filters(payload)
      add_facets(payload) if facets?
      add_suggest_fields(payload) if suggest?
      apply_highlighting(payload) if highlight?

      @payload
    end

    def results
      @results ||= execute
    end

    private

    # create the payload and return the results
    def execute
      search, response = search(payload)
      apply_facet_limits(response)

      Searchkick::Results.new(response, search.options.merge(term: term))
    end

    def fields
      @fields ||= if options[:fields]
        if options[:autocomplete]
          options[:fields].map{ |f| "#{f}.autocomplete" }
        else
          options[:fields].map do |value|
            k, v = value.is_a?(Hash) ? value.to_a.first : [value, :word]
            "#{k}.#{v == :word ? "analyzed" : v}"
          end
        end
      else
        if options[:autocomplete]
          (searchkick_options[:autocomplete] || []).map{ |f| "#{f}.autocomplete" }
        else
          ["_all"]
        end
      end
    end

    def operator
      @operator ||= options[:partial] ? "or" : "and"
    end

    # model and eager loading
    def load
      return @load if defined?(@load)

      @load = options[:load].nil? ? true : options[:load]
      @load = (options[:include] ? { include: options[:include] } : true) if @load

      @load
    end

    # pagination page
    def page
      @page ||= [options[:page].to_i, 1].max
    end

    # pagination size
    def per_page
      @per_page ||= (options[:limit] || options[:per_page] || 100000).to_i
    end

    # pagination offset
    def offset
      @offset ||= options[:offset] || (page - 1) * per_page
    end

    def index_name
      @index_name ||= options[:index_name] || searchkick_index.name
    end

    def conversions_field
      searchkick_options[:conversions]
    end

    def personalize_field
      searchkick_options[:personalize]
    end

    # match all results
    def all?
      term == "*"
    end

    def query
      if options[:query]
        query = options[:query]
      elsif options[:similar]
        query = {
          more_like_this: {
            fields: fields,
            like_text: term,
            min_doc_freq: 1,
            min_term_freq: 1,
            analyzer: "searchkick_search2"
          }
        }
      elsif all?
        query = {
          match_all: {}
        }
      else
        if options[:autocomplete]
          query = {
            multi_match: {
              fields: fields,
              query: term,
              analyzer: "searchkick_autocomplete_search"
            }
          }
        else
          queries = []
          fields.each do |field|
            if field == "_all" or field.end_with?(".analyzed")
              shared_options = {
                fields: [field],
                query: term,
                use_dis_max: false,
                operator: operator,
                cutoff_frequency: 0.001
              }
              queries.concat [
                {multi_match: shared_options.merge(boost: 10, analyzer: "searchkick_search")},
                {multi_match: shared_options.merge(boost: 10, analyzer: "searchkick_search2")}
              ]
              if options[:misspellings] != false
                distance = (options[:misspellings].is_a?(Hash) && options[:misspellings][:distance]) || 1
                queries.concat [
                  {multi_match: shared_options.merge(fuzziness: distance, max_expansions: 3, analyzer: "searchkick_search")},
                  {multi_match: shared_options.merge(fuzziness: distance, max_expansions: 3, analyzer: "searchkick_search2")}
                ]
              end
            else
              queries << {
                multi_match: {
                  fields: [field],
                  query: term,
                  analyzer: "searchkick_autocomplete_search"
                }
              }
            end
          end

          query = {
            dis_max: {
              queries: queries
            }
          }
        end

        if conversions_field and options[:conversions] != false
          # wrap query in a bool query
          query = {
            bool: {
              must: query,
              should: {
                nested: {
                  path: conversions_field,
                  score_mode: "total",
                  query: {
                    custom_score: {
                      query: {
                        match: {
                          query: term
                        }
                      },
                      script: "doc['count'].value"
                    }
                  }
                }
              }
            }
          }
        end
      end

      query
    end

    def custom_filters?
      custom_filters.any?
    end

    def custom_filters
      return @custom_filters if defined?(@custom_filters)

      @custom_filters = []
      @custom_filters << boost_custom_filter if boost?
      @custom_filters << personalize_custom_filter if personalized?
      @custom_filters
    end

    def boost?
      !!options[:boost]
    end

    def boost_custom_filter
      {
        filter: {
          exists: {
            field: options[:boost]
          }
        },
        script: "log(doc['#{options[:boost]}'].value + 2.718281828)"
      }
    end

    def personalized?
      options[:user_id] && personalize_field
    end

    def personalize_custom_filter
      {
        filter: {
          term: {
            personalize_field => options[:user_id]
          }
        },
        boost: 100
      }
    end

    def apply_custom_filters(payload)
      payload[:query] = {
        custom_filters_score: {
          query: payload[:query],
          filters: custom_filters,
          score_mode: "total"
        }
      }
    end

    def explain?
      !!options[:explain]
    end

    def apply_explain(payload)
      payload[:explain] = options[:explain]
    end

    def order?
      !!options[:order]
    end

    def apply_order(payload)
      order = options[:order].is_a?(Enumerable) ? options[:order] : {options[:order] => :asc}
      payload[:sort] = order
    end

    def apply_where_filters(payload)
      filters = where_filters(options[:where])
      if filters.any?
        payload[:filter] = {
          and: filters
        }
      end
    end

    def facets?
      !!options[:facets]
    end

    def add_facets(payload)
      facets = options[:facets] || {}

      if facets.is_a?(Array) # convert to more advanced syntax
        facets = Hash[ facets.map{|f| [f, {}] } ]
      end

      payload[:facets] = {}
      facets.each do |field, facet_options|
        # ask for extra facets due to
        # https://github.com/elasticsearch/elasticsearch/issues/1305

        if facet_options[:ranges]
          payload[:facets][field] = {
            range: {
              field.to_sym => facet_options[:ranges]
            }
          }
        else
          payload[:facets][field] = {
            terms: {
              field: field,
              size: facet_options[:limit] ? facet_options[:limit] + 150 : 100000
            }
          }
        end

        @facet_limits[field] = facet_options[:limit] if facet_options[:limit]

        # offset is not possible
        # http://elasticsearch-users.115913.n3.nabble.com/Is-pagination-possible-in-termsStatsFacet-td3422943.html

        facet_filters = where_filters(facet_options[:where])
        if facet_filters.any?
          payload[:facets][field][:facet_filter] = {
            and: {
              filters: facet_filters
            }
          }
        end
      end
    end

    def suggest?
      !!options[:suggest]
    end

    def add_suggest_fields(payload)
      suggest_fields = (searchkick_options[:suggest] || []).map(&:to_s)

      # intersection
      suggest_fields = suggest_fields & options[:fields].map(&:to_s) if options[:fields]

      if suggest_fields.any?
        payload[:suggest] = { text: term }
        suggest_fields.each do |field|
          payload[:suggest][field] = {
            phrase: {
              field: "#{field}.suggest"
            }
          }
        end
      end
    end

    def highlight?
      !!options[:highlight]
    end

    def apply_highlighting(payload)
      payload[:highlight] = {
        fields: Hash[ fields.map{|f| [f, {}] } ]
      }

      if options[:highlight].is_a?(Hash) and tag = options[:highlight][:tag]
        payload[:highlight][:pre_tags] = [tag]
        payload[:highlight][:post_tags] = [tag.to_s.gsub(/\A</, "</")]
      end
    end

    # pass the payload to Tire and return the search object and the response
    def search(payload)
      # An empty array will cause only the _id and _type for each hit to be returned
      # http://www.elasticsearch.org/guide/reference/api/search/fields/
      payload[:fields] = [] if load

      tire_options = {
        load: load,
        payload: payload,
        size: per_page,
        from: offset
      }
      tire_options[:type] = document_type if klass != searchkick_klass

      search = Tire::Search::Search.new(index_name, tire_options)
      begin
        response = search.json
      rescue Tire::Search::SearchRequestFailed => e
        status_code = e.message[0..3].to_i
        if status_code == 404
          raise "Index missing - run #{searchkick_klass.name}.reindex"
        elsif status_code == 500 and (e.message.include?("IllegalArgumentException[minimumSimilarity >= 1]") or e.message.include?("No query registered for [multi_match]"))
          raise "Upgrade Elasticsearch to 0.90.0 or greater"
        else
          raise e
        end
      end

      return search, response
    end

    # apply facet limit in client due to
    # https://github.com/elasticsearch/elasticsearch/issues/1305
    def apply_facet_limits(response)
      @facet_limits.each do |field, limit|
        field = field.to_s
        facet = response["facets"][field]
        response["facets"][field]["terms"] = facet["terms"].first(limit)
        response["facets"][field]["other"] = facet["total"] - facet["terms"].sum{|term| term["count"] }
      end
    end

    ## Helpers

    # transform a set of conditions into where statements for the payload
    def where_filters(conditions)
      conditions = conditions || {}
      filters = []

      conditions.each do |field, value|
        field = :_id if field.to_s == "id"

        if field == :or
          value.each do |or_clause|
            filters << {or: or_clause.map{|or_statement| {and: where_filters(or_statement)} }}
          end
        else
          # expand ranges
          if value.is_a?(Range)
            value = {gte: value.first, (value.exclude_end? ? :lt : :lte) => value.last}
          end

          if value.is_a?(Hash)
            if value[:near]
              filters << {
                geo_distance: {
                  field => value[:near].map(&:to_f).reverse,
                  distance: value[:within] || "50mi"
                }
              }
            end

            if value[:top_left]
              filters << {
                geo_bounding_box: {
                  field => {
                    top_left: value[:top_left].map(&:to_f).reverse,
                    bottom_right: value[:bottom_right].map(&:to_f).reverse
                  }
                }
              }
            end

            value.each do |op, op_value|
              if op == :not # not equal
                filters << { not: term_filters(field, op_value) }
              elsif op == :all
                filters << { terms: { field => op_value, execution: "and" } }
              elsif [:gt, :gte, :lt, :lte].include?(op)
                range_query =
                  case op
                  when :gt
                    { from: op_value, include_lower: false }
                  when :gte
                    { from: op_value, include_lower: true }
                  when :lt
                    { to: op_value, include_upper: false }
                  when :lte
                    { to: op_value, include_upper: true }
                  end

                filters << { range: { field => range_query } }
              end
            end
          else
            filters << term_filters(field, value)
          end
        end
      end

      filters
    end

    # create a condition to match the given field to the given value
    def term_filters(field, value)
      if value.is_a?(Array) # in query
        { or: value.map{|v| term_filters(field, v) } }
      elsif value.nil?
        { missing: { "field" => field, existence: true, null_value: true } }
      else
        { term: { field => value } }
      end
    end

  end
end