module Searchkick
  module Search

    def search(term, options = {})
      if term.is_a?(Hash)
        options = term
        term = nil
      else
        term = term.to_s
      end

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

      operator = options[:partial] ? "or" : "and"

      # model and eagar loading
      load = options[:load].nil? ? true : options[:load]
      load = (options[:include] ? {include: options[:include]} : true) if load

      # pagination
      page = [options[:page].to_i, 1].max
      per_page = (options[:limit] || options[:per_page] || 100000).to_i
      offset = options[:offset] || (page - 1) * per_page
      index_name = options[:index_name] || searchkick_index.name

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

      if options[:personalize]
        custom_filters << {
          filter: {
            term: options[:personalize]
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
        payload[:sort] = Hash[ order.map{|k, v| [k.to_s == "id" ? :_id : k, v] } ]
      end

      term_filters =
        proc do |field, value|
          if value.is_a?(Array) # in query
            if value.any?
              {or: value.map{|v| term_filters.call(field, v) }}
            else
              {terms: {field => value}} # match nothing
            end
          elsif value.nil?
            {missing: {"field" => field, existence: true, null_value: true}}
          else
            {term: {field => value}}
          end
        end

      # where
      where_filters =
        proc do |where|
          filters = []
          (where || {}).each do |field, value|
            field = :_id if field.to_s == "id"

            if field == :or
              value.each do |or_clause|
                filters << {or: or_clause.map{|or_statement| {and: where_filters.call(or_statement)} }}
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
                    filters << {not: term_filters.call(field, op_value)}
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
                    filters << {range: {field => range_query}}
                  end
                end
              else
                filters << term_filters.call(field, value)
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

          facet_filters = where_filters.call(facet_options[:where])
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

      # An empty array will cause only the _id and _type for each hit to be returned
      # http://www.elasticsearch.org/guide/reference/api/search/fields/
      payload[:fields] = [] if load

      tire_options = {load: load, payload: payload, size: per_page, from: offset}
      tire_options[:type] = document_type if self != searchkick_klass
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

      # apply facet limit in client due to
      # https://github.com/elasticsearch/elasticsearch/issues/1305
      facet_limits.each do |field, limit|
        field = field.to_s
        facet = response["facets"][field]
        response["facets"][field]["terms"] = facet["terms"].first(limit)
        response["facets"][field]["other"] = facet["total"] - facet["terms"].sum{|term| term["count"] }
      end

      Searchkick::Results.new(response, search.options.merge(term: term))
    end

  end
end
