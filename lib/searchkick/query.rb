module Searchkick
  class Query
    attr_reader :klass, :term, :options
    attr_accessor :body

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

      fields =
        if options[:fields]
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

      operator = options[:operator] || (options[:partial] ? "or" : "and")

      # pagination
      page = [options[:page].to_i, 1].max
      per_page = (options[:limit] || options[:per_page] || 100000).to_i
      padding = [options[:padding].to_i, 0].max
      offset = options[:offset] || (page - 1) * per_page + padding

      conversions_field = searchkick_options[:conversions]
      personalize_field = searchkick_options[:personalize]

      all = term == "*"

      if options[:query]
        payload = options[:query]
      elsif options[:similar]
        payload = {
          more_like_this: {
            fields: fields,
            like_text: term,
            min_doc_freq: 1,
            min_term_freq: 1,
            analyzer: "searchkick_search2"
          }
        }
      elsif all
        payload = {
          match_all: {}
        }
      else
        if options[:autocomplete]
          payload = {
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
                operator: operator
              }
              shared_options[:cutoff_frequency] = 0.001 unless operator == "and"
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

          payload = {
            dis_max: {
              queries: queries
            }
          }
        end

        if conversions_field and options[:conversions] != false
          # wrap payload in a bool query
          payload = {
            bool: {
              must: payload,
              should: {
                nested: {
                  path: conversions_field,
                  score_mode: "total",
                  query: {
                    function_score: {
                      boost_mode: "replace",
                      query: {
                        match: {
                          query: term
                        }
                      },
                      script_score: {
                        script: "doc['count'].value"
                      }
                    }
                  }
                }
              }
            }
          }
        end
      end

      custom_filters = []

      if options[:boost]
        custom_filters << {
          filter: {
            exists: {
              field: options[:boost]
            }
          },
          script_score: {
            script: "log(doc['#{options[:boost]}'].value + 2.718281828)"
          }
        }
      end

      if options[:user_id] and personalize_field
        custom_filters << {
          filter: {
            term: {
              personalize_field => options[:user_id]
            }
          },
          boost_factor: 100
        }
      end

      if options[:personalize]
        custom_filters << {
          filter: {
            term: options[:personalize]
          },
          boost_factor: 100
        }
      end

      if custom_filters.any?
        payload = {
          function_score: {
            functions: custom_filters,
            query: payload,
            score_mode: "sum"
          }
        }
      end

      payload = {
        query: payload,
        size: per_page,
        from: offset
      }
      payload[:explain] = options[:explain] if options[:explain]

      # order
      if options[:order]
        order = options[:order].is_a?(Enumerable) ? options[:order] : {options[:order] => :asc}
        payload[:sort] = Hash[ order.map{|k, v| [k.to_s == "id" ? :_id : k, v] } ]
      end

      # filters
      filters = where_filters(options[:where])
      if filters.any?
        payload[:filter] = {
          and: filters
        }
      end

      # facets
      facet_limits = {}
      if options[:facets]
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
          elsif facet_options[:stats]
            payload[:facets][field] = {
              terms_stats: {
                key_field: field,
                value_script: 'doc.score',
                size: facet_options[:limit] ? facet_options[:limit] + 150 : 100000
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

          facet_limits[field] = facet_options[:limit] if facet_options[:limit]

          # offset is not possible
          # http://elasticsearch-users.115913.n3.nabble.com/Is-pagination-possible-in-termsStatsFacet-td3422943.html

          facet_options.deep_merge!(where: options[:where].reject{|k| k == field}) if options[:smart_facets] == true
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

      # suggestions
      if options[:suggest]
        suggest_fields = (searchkick_options[:suggest] || []).map(&:to_s)

        # intersection
        if options[:fields]
          suggest_fields = suggest_fields & options[:fields].map{|v| (v.is_a?(Hash) ? v.keys.first : v).to_s }
        end

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

      # highlight
      if options[:highlight]
        payload[:highlight] = {
          fields: Hash[ fields.map{|f| [f, {}] } ]
        }
        if options[:highlight].is_a?(Hash) and tag = options[:highlight][:tag]
          payload[:highlight][:pre_tags] = [tag]
          payload[:highlight][:post_tags] = [tag.to_s.gsub(/\A</, "</")]
        end
      end

      # model and eagar loading
      load = options[:load].nil? ? true : options[:load]

      # An empty array will cause only the _id and _type for each hit to be returned
      # http://www.elasticsearch.org/guide/reference/api/search/fields/
      payload[:fields] = [] if load

      if options[:type] or klass != searchkick_klass
        @type = [options[:type] || klass].flatten.map{|v| searchkick_index.klass_document_type(v) }
      end

      @body = payload
      @facet_limits = facet_limits
      @page = page
      @per_page = per_page
      @padding = padding
      @load = load
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

    def params
      params = {
        index: options[:index_name] || searchkick_index.name,
        body: body
      }
      params.merge!(type: @type) if @type
      params
    end

    def execute
      begin
        response = Searchkick.client.search(params)
      rescue => e # TODO rescue type
        status_code = e.message[1..3].to_i
        if status_code == 404
          raise MissingIndexError, "Index missing - run #{searchkick_klass.name}.reindex"
        elsif status_code == 500 and (
            e.message.include?("IllegalArgumentException[minimumSimilarity >= 1]") or
            e.message.include?("No query registered for [multi_match]") or
            e.message.include?("[match] query does not support [cutoff_frequency]]") or
            e.message.include?("No query registered for [function_score]]")
          )

          raise UnsupportedVersionError, "This version of Searchkick requires Elasticsearch 0.90.4 or greater"
        elsif status_code == 400
          if e.message.include?("[multi_match] analyzer [searchkick_search] not found")
            raise InvalidQueryError, "Bad mapping - run #{searchkick_klass.name}.reindex"
          else
            raise InvalidQueryError, e.message
          end
        else
          raise e
        end
      end

      # apply facet limit in client due to
      # https://github.com/elasticsearch/elasticsearch/issues/1305
      @facet_limits.each do |field, limit|
        field = field.to_s
        facet = response["facets"][field]
        response["facets"][field]["terms"] = facet["terms"].first(limit)
        response["facets"][field]["other"] = facet["total"] - facet["terms"].sum{|term| term["count"] }
      end

      opts = {
        page: @page,
        per_page: @per_page,
        padding: @padding,
        load: @load,
        includes: options[:include] || options[:includes]
      }
      Searchkick::Results.new(searchkick_klass, response, opts)
    end

    private

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

          if value.is_a?(Array)
            value = {in: value}
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
              when :in
                filters << term_filters(field, op_value)
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
