module Searchkick
  module Search

    def search(term, options = {})
      term = term.to_s
      fields =
        if options[:fields]
          if options[:autocomplete]
            options[:fields].map{|f| "#{f}.autocomplete" }
          else
            options[:fields].map{|f| "#{f}.analyzed" }
          end
        else
          if options[:autocomplete]
            (@searchkick_options[:autocomplete] || []).map{|f| "#{f}.autocomplete" }
          else
            ["_all"]
          end
        end

      operator = options[:partial] ? "or" : "and"

      # model and eagar loading
      load = options[:load].nil? ? true : options[:load]
      load = (options[:include] ? {include: options[:include]} : true) if load

      # pagination
      page = [options[:page].to_i, 1].max
      per_page = (options[:limit] || options[:per_page] || 100000).to_i
      offset = options[:offset] || (page - 1) * per_page
      index_name = options[:index_name] || tire.index.name

      conversions_field = @searchkick_options[:conversions]
      personalize_field = @searchkick_options[:personalize]

      all = term == "*"

      if options[:similar]
        payload = {
          more_like_this: {
            fields: fields,
            like_text: term,
            min_doc_freq: 1,
            min_term_freq: 1
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
          shared_options = {
            fields: fields,
            query: term,
            use_dis_max: false,
            operator: operator
          }
          queries = [
            {multi_match: shared_options.merge(boost: 10, analyzer: "searchkick_search")},
            {multi_match: shared_options.merge(boost: 10, analyzer: "searchkick_search2")}
          ]
          if options[:misspellings] != false
            queries.concat [
              {multi_match: shared_options.merge(fuzziness: 1, max_expansions: 3, analyzer: "searchkick_search")},
              {multi_match: shared_options.merge(fuzziness: 1, max_expansions: 3, analyzer: "searchkick_search2")}
            ]
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

      custom_filters = []

      if options[:boost]
        custom_filters << {
          filter: {
            exists: {
              field: options[:boost]
            }
          },
          script: "log(doc['#{options[:boost]}'].value + 2.718281828)"
        }
      end

      if options[:user_id] and personalize_field
        custom_filters << {
          filter: {
            term: {
              personalize_field => options[:user_id]
            }
          },
          boost: 100
        }
      end

      if custom_filters.any?
        payload = {
          custom_filters_score: {
            query: payload,
            filters: custom_filters,
            score_mode: "total"
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
        payload[:sort] = order
      end

      # where
      # TODO expand or
      where_filters =
        proc do |where|
          filters = []
          (where || {}).each do |field, value|
            if field == :or
              value.each do |or_clause|
                filters << {or: or_clause.map{|or_statement| {term: or_statement} }}
              end
            else
              # expand ranges
              if value.is_a?(Range)
                value = {gte: value.first, (value.exclude_end? ? :lt : :lte) => value.last}
              end

              if value.is_a?(Array) # in query
                filters << {terms: {field => value}}
              elsif value.is_a?(Hash)
                if value[:near]
                  filters << {
                    geo_distance: {
                      field => value.delete(:near),
                      distance: value.delete(:within) || "50mi"
                    }
                  }
                end

                value.each do |op, op_value|
                  if op == :not # not equal
                    if op_value.is_a?(Array)
                      filters << {not: {terms: {field => op_value}}}
                    else
                      filters << {not: {term: {field => op_value}}}
                    end
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
                    filters << {range: {field => range_query}}
                  end
                end
              else
                filters << {term: {field => value}}
              end
            end
          end
          filters
        end

      # filters
      filters = where_filters.call(options[:where])
      if filters.any?
        payload[:filter] = {
          and: filters
        }
      end

      # facets
      if options[:facets]
        facets = options[:facets] || {}
        if facets.is_a?(Array) # convert to more advanced syntax
          facets = Hash[ facets.map{|f| [f, {}] } ]
        end

        payload[:facets] = {}
        facets.each do |field, facet_options|
          payload[:facets][field] = {
            terms: {
              field: field,
              size: facet_options[:limit] || 100000
            }
          }

          # offset is not possible
          # http://elasticsearch-users.115913.n3.nabble.com/Is-pagination-possible-in-termsStatsFacet-td3422943.html

          facet_filters = where_filters.call(facet_options[:where])
          if facet_filters
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
        suggest_fields = (@searchkick_options[:suggest] || []).map(&:to_s)
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

      # An empty array will cause only the _id and _type for each hit to be returned
      # http://www.elasticsearch.org/guide/reference/api/search/fields/
      payload[:fields] = [] if load

      search = Tire::Search::Search.new(index_name, load: load, payload: payload, size: per_page, from: offset)
      Searchkick::Results.new(search.json, search.options.merge(term: term))
    end

  end
end
