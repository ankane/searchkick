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

    def searchkick_index
      klass.searchkick_index
    end

    def searchkick_options
      klass.searchkick_options
    end

    def searchkick_klass
      klass.searchkick_klass
    end

    def document_type
      klass.document_type
    end

    def results
      @results ||= execute
    end

    # construct the payload from the provided options
    def payload
      return @payload if defined?(@payload)

      @payload = {
        query: query,
        size: per_page,
        from: offset
      }

      apply_custom_filters(@payload) if custom_filters?
      apply_explain(@payload) if explain?
      apply_order(@payload) if order?
      apply_where_filters(@payload)
      add_facets(@payload) if facets?
      add_suggest_fields(@payload) if suggest?
      apply_highlighting(@payload) if highlight?

      @payload
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
          options[:fields].map{|f| "#{f}.autocomplete" }
        else
          options[:fields].map do |value|
            k, v = value.is_a?(Hash) ? value.to_a.first : [value, :word]
            "#{k}.#{v == :word ? "analyzed" : v}"
          end
        end
      else
        if options[:autocomplete]
          (searchkick_options[:autocomplete] || []).map{|f| "#{f}.autocomplete" }
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
      @load = (options[:include] ? {include: options[:include]} : true) if @load

      @load
    end

    # pagination page
    def page
      @page ||= [options[:page].to_i, 1].max
    end

    # pagination window
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
            if field == "_all" || field.end_with?(".analyzed")
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
              analyzer = field.match(/\.word_(start|middle|end)\z/) ? "searchkick_word_search" : "searchkick_autocomplete_search"
              queries << {
                multi_match: {
                  fields: [field],
                  query: term,
                  analyzer: analyzer
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

        if conversions_field && options[:conversions] != false
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
      @custom_filters << personalize_for_user_custom_filter if personalized_for_user?
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

    def personalized_for_user?
      options[:user_id] && personalize_field
    end

    def personalize_for_user_custom_filter
      {
        filter: {
          term: {
            personalize_field => options[:user_id]
          }
        },
        boost: 100
      }
    end

    def personalized?
      !!options[:personalize]
    end

    def personalize_custom_filter
      {
        filter: {
          term: options[:personalize]
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

    def add_underscore_to_id_keys(hash)
      Hash[ hash.map{|k, v| [k.to_s == "id" ? :_id : k, v] } ]
    end

    def apply_order(payload)
      order = if options[:order].is_a?(Enumerable)
        options[:order]
      else
        {options[:order] => :asc}
      end

      order = if order.is_a?(Array)
        order.map { |hash| add_underscore_to_id_keys(hash) }
      else
        add_underscore_to_id_keys(order)
      end

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
        payload[:suggest] = {text: term}
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

      if options[:highlight].is_a?(Hash) && (tag = options[:highlight][:tag])
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

      if options[:type] || klass != searchkick_klass
        tire_options[:type] = [options[:type] || klass].flatten.map(&:document_type)
      end

      search = Tire::Search::Search.new(index_name, tire_options)
      begin
        response = search.json
      rescue Tire::Search::SearchRequestFailed => e
        status_code = e.message[0..3].to_i
        if status_code == 404
          raise "Index missing - run #{searchkick_klass.name}.reindex"
        elsif status_code == 500 && ((e.message.include?("IllegalArgumentException[minimumSimilarity >= 1]") || e.message.include?("No query registered for [multi_match]")))
          raise "Upgrade Elasticsearch to 0.90.0 or greater"
        else
          raise e
        end
      end

      return search, response
    end

    private

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

    def where_filters(where)
      filters = []
      (where || {}).each do |field, value|
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
            value.each do |op, op_value|
              case op
              when :within, :bottom_right
                # do nothing
              when :near
                filters << {
                  geo_distance: {
                    field => op_value.map(&:to_f).reverse,
                    distance: value[:within] || "50mi"
                  }
                }
              when :top_left
                filters << {
                  geo_bounding_box: {
                    field => {
                      top_left: op_value.map(&:to_f).reverse,
                      bottom_right: value[:bottom_right].map(&:to_f).reverse
                    }
                  }
                }
              when :not # not equal
                filters << {not: term_filters(field, op_value)}
              when :all
                filters << {terms: {field => op_value, execution: "and"}}
              else
                range_query =
                  case op
                  when :gt
                    {from: op_value, include_lower: false}
                  when :gte
                    {from: op_value, include_lower: true}
                  when :lt
                    {to: op_value, include_upper: false}
                  when :lte
                    {to: op_value, include_upper: true}
                  else
                    raise "Unknown where operator"
                  end
                # issue 132
                if existing = filters.find{ |f| f[:range] && f[:range][field] }
                  existing[:range][field].merge!(range_query)
                else
                  filters << {range: {field => range_query}}
                end
              end
            end
          else
            filters << term_filters(field, value)
          end
        end
      end
      filters
    end

    def term_filters(field, value)
      if value.is_a?(Array) # in query
        if value.any?
          {or: value.map{|v| term_filters(field, v) }}
        else
          {terms: {field => value}} # match nothing
        end
      elsif value.nil?
        {missing: {"field" => field, existence: true, null_value: true}}
      else
        {term: {field => value}}
      end
    end

  end
end