module Searchkick
  class Query
    attr_reader :klass, :term, :options
    attr_accessor :body

    def initialize(klass, term, options = {})
      if term.is_a?(Hash)
        options = term
        term = "*"
      else
        term = term.to_s
      end

      @klass = klass
      @term = term
      @options = options

      boost_fields = {}
      fields =
        if options[:fields]
          if options[:autocomplete]
            options[:fields].map { |f| "#{f}.autocomplete" }
          else
            options[:fields].map do |value|
              k, v = value.is_a?(Hash) ? value.to_a.first : [value, :word]
              k2, boost = k.to_s.split("^", 2)
              field = "#{k2}.#{v == :word ? 'analyzed' : v}"
              boost_fields[field] = boost.to_f if boost
              field
            end
          end
        else
          if options[:autocomplete]
            (searchkick_options[:autocomplete] || []).map { |f| "#{f}.autocomplete" }
          else
            ["_all"]
          end
        end

      operator = options[:operator] || (options[:partial] ? "or" : "and")

      # pagination
      page = [options[:page].to_i, 1].max
      per_page = (options[:limit] || options[:per_page] || 100_000).to_i
      padding = [options[:padding].to_i, 0].max
      offset = options[:offset] || (page - 1) * per_page + padding

      # model and eagar loading
      load = options[:load].nil? ? true : options[:load]

      conversions_field = searchkick_options[:conversions]
      personalize_field = searchkick_options[:personalize]

      all = term == "*"
      facet_limits = {}

      options[:json] ||= options[:body]
      if options[:json]
        payload = options[:json]
      else
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
              qs = []

              factor = boost_fields[field] || 1
              shared_options = {
                query: term,
                operator: operator,
                boost: 10 * factor
              }

              misspellings =
                if options.key?(:misspellings)
                  options[:misspellings]
                elsif options.key?(:mispellings)
                  options[:mispellings] # why not?
                elsif field == "_all" || field.end_with?(".analyzed")
                  true
                else
                  # TODO default to true and remove this
                  false
                end

              if misspellings != false
                edit_distance = (misspellings.is_a?(Hash) && (misspellings[:edit_distance] || misspellings[:distance])) || 1
                transpositions = (misspellings.is_a?(Hash) && misspellings[:transpositions] == true) ? {fuzzy_transpositions: true} : {}
                prefix_length = (misspellings.is_a?(Hash) && misspellings[:prefix_length]) || 0
              end

              if field == "_all" || field.end_with?(".analyzed")
                shared_options[:cutoff_frequency] = 0.001 unless operator == "and" || misspellings == false
                qs.concat [
                  shared_options.merge(analyzer: "searchkick_search"),
                  shared_options.merge(analyzer: "searchkick_search2")
                ]
              elsif field.end_with?(".exact")
                f = field.split(".")[0..-2].join(".")
                queries << {match: {f => shared_options.merge(analyzer: "keyword")}}
              else
                analyzer = field.match(/\.word_(start|middle|end)\z/) ? "searchkick_word_search" : "searchkick_autocomplete_search"
                qs << shared_options.merge(analyzer: analyzer)
              end

              if misspellings != false
                qs.concat qs.map { |q| q.except(:cutoff_frequency).merge(fuzziness: edit_distance, prefix_length: prefix_length, max_expansions: 3, boost: factor).merge(transpositions) }
              end

              queries.concat(qs.map { |q| {match: {field => q}} })
            end

            payload = {
              dis_max: {
                queries: queries
              }
            }
          end

          if conversions_field && options[:conversions] != false
            # wrap payload in a bool query
            script_score =
              if below12?
                {script_score: {script: "doc['count'].value"}}
              else
                {field_value_factor: {field: "count"}}
              end

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
                        }
                      }.merge(script_score)
                    }
                  }
                }
              }
            }
          end
        end

        custom_filters = []
        multiply_filters = []

        boost_by = options[:boost_by] || {}

        if boost_by.is_a?(Array)
          boost_by = Hash[boost_by.map { |f| [f, {factor: 1}] }]
        elsif boost_by.is_a?(Hash)
          multiply_by, boost_by = boost_by.partition { |k,v| v[:boost_mode] == "multiply" }.map{ |i| Hash[i] }
        end
        if options[:boost]
          boost_by[options[:boost]] = {factor: 1}
        end

        custom_filters.concat boost_filters(boost_by, log: true)
        multiply_filters.concat boost_filters(multiply_by || {})

        boost_where = options[:boost_where] || {}
        if options[:user_id] && personalize_field
          boost_where[personalize_field] = options[:user_id]
        end
        if options[:personalize]
          boost_where = boost_where.merge(options[:personalize])
        end
        boost_where.each do |field, value|
          if value.is_a?(Array) && value.first.is_a?(Hash)
            value.each do |value_factor|
              value, factor = value_factor[:value], value_factor[:factor]
              custom_filters << custom_filter(field, value, factor)
            end
          elsif value.is_a?(Hash)
            value, factor = value[:value], value[:factor]
            custom_filters << custom_filter(field, value, factor)
          else
            factor = 1000
            custom_filters << custom_filter(field, value, factor)
          end
        end

        boost_by_distance = options[:boost_by_distance]
        if boost_by_distance
          boost_by_distance = {function: :gauss, scale: "5mi"}.merge(boost_by_distance)
          if !boost_by_distance[:field] || !boost_by_distance[:origin]
            raise ArgumentError, "boost_by_distance requires :field and :origin"
          end
          function_params = boost_by_distance.select { |k, v| [:origin, :scale, :offset, :decay].include?(k) }
          function_params[:origin] = function_params[:origin].reverse
          custom_filters << {
            boost_by_distance[:function] => {
              boost_by_distance[:field] => function_params
            }
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

        if multiply_filters.any?
          payload = {
            function_score: {
              functions: multiply_filters,
              query: payload,
              score_mode: "multiply"
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
          # TODO id transformation for arrays
          payload[:sort] = order.is_a?(Array) ? order : Hash[order.map { |k, v| [k.to_s == "id" ? :_id : k, v] }]
        end

        # filters
        filters = where_filters(options[:where])

        # nested filter
        if nested_filter_value = options[:nested]
         filters << {
           nested: {
             path: nested_filter_value[:path],
             filter: { and: where_filters(nested_filter_value[:where]) }
           }
         }
        end

        if filters.any?
          if options[:facets]
            payload[:filter] = {
              and: filters
            }
          else
            # more efficient query if no facets
            payload[:query] = {
              filtered: {
                query: payload[:query],
                filter: {
                  and: filters
                }
              }
            }
          end
        end

        # facets
        if options[:facets]
          facets = options[:facets] || {}
          if facets.is_a?(Array) # convert to more advanced syntax
            facets = Hash[facets.map { |f| [f, {}] }]
          end

          payload[:facets] = {}
          facets.each do |field, facet_options|
            # ask for extra facets due to
            # https://github.com/elasticsearch/elasticsearch/issues/1305
            size = facet_options[:limit] ? facet_options[:limit] + 150 : 100_000

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
                  value_script: below14? ? "doc.score" : "_score",
                  size: size
                }
              }
            else
              payload[:facets][field] = {
                terms: {
                  field: facet_options[:field] || field,
                  size: size
                }
              }
            end

            facet_limits[field] = facet_options[:limit] if facet_options[:limit]

            # offset is not possible
            # http://elasticsearch-users.115913.n3.nabble.com/Is-pagination-possible-in-termsStatsFacet-td3422943.html

            facet_options.deep_merge!(where: options.fetch(:where, {}).reject { |k| k == field } ) if options[:smart_facets] == true
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
            suggest_fields &= options[:fields].map { |v| (v.is_a?(Hash) ? v.keys.first : v).to_s.split("^", 2).first }
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
            fields: Hash[fields.map { |f| [f, {}] }]
          }

          if options[:highlight].is_a?(Hash)
            if (tag = options[:highlight][:tag])
              payload[:highlight][:pre_tags] = [tag]
              payload[:highlight][:post_tags] = [tag.to_s.gsub(/\A</, "</")]
            end

            if (fragment_size = options[:highlight][:fragment_size])
              payload[:highlight][:fragment_size] = fragment_size
            end

            highlight_fields = options[:highlight][:fields]
            if highlight_fields
              payload[:highlight][:fields] = {}

              highlight_fields.each do |name, opts|
                payload[:highlight][:fields]["#{name}.analyzed"] = opts || {}
              end
            end
          end
        end

        # An empty array will cause only the _id and _type for each hit to be returned
        # http://www.elasticsearch.org/guide/reference/api/search/fields/
        if options[:select]
          payload[:fields] = options[:select] if options[:select] != true
        elsif load
          payload[:fields] = []
        end

        if options[:type] || klass != searchkick_klass
          @type = [options[:type] || klass].flatten.map { |v| searchkick_index.klass_document_type(v) }
        end

        # routing
        if options[:routing]
          @routing = options[:routing]
        end
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
      params.merge!(routing: @routing) if @routing
      params
    end

    def execute
      begin
        response = Searchkick.client.search(params)
      rescue => e # TODO rescue type
        status_code = e.message[1..3].to_i
        if status_code == 404
          raise MissingIndexError, "Index missing - run #{searchkick_klass.name}.reindex"
        elsif status_code == 500 && (
            e.message.include?("IllegalArgumentException[minimumSimilarity >= 1]") ||
            e.message.include?("No query registered for [multi_match]") ||
            e.message.include?("[match] query does not support [cutoff_frequency]]") ||
            e.message.include?("No query registered for [function_score]]")
          )

          raise UnsupportedVersionError, "This version of Searchkick requires Elasticsearch 1.0 or greater"
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
        response["facets"][field]["other"] = facet["total"] - facet["terms"].sum { |term| term["count"] }
      end

      opts = {
        page: @page,
        per_page: @per_page,
        padding: @padding,
        load: @load,
        includes: options[:include] || options[:includes],
        json: !options[:json].nil?
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
            filters << {or: or_clause.map { |or_statement| {and: where_filters(or_statement)} }}
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
              when :regexp # support for regexp queries without using a regexp ruby object
                filters << {regexp: {field => {value: op_value}}}
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
                if (existing = filters.find { |f| f[:range] && f[:range][field] })
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
        if value.any?(&:nil?)
          {or: [term_filters(field, nil), term_filters(field, value.compact)]}
        else
          {in: {field => value}}
        end
      elsif value.nil?
        {missing: {"field" => field, existence: true, null_value: true}}
      elsif value.is_a?(Regexp)
        {regexp: {field => {value: value.source}}}
      else
        {term: {field => value}}
      end
    end

    def custom_filter(field, value, factor)
      {
        filter: {
          and: where_filters({field => value})
        },
        boost_factor: factor
      }
    end

    def boost_filters(boost_by, options = {})
      boost_by.map do |field, value|
        log = value.key?(:log) ? value[:log] : options[:log]
        value[:factor] ||= 1
        script_score =
          if below12?
            script = log ? "log(doc['#{field}'].value + 2.718281828)" : "doc['#{field}'].value"
            {script_score: {script: "#{value[:factor].to_f} * #{script}"}}
          else
            {field_value_factor: {field: field, factor: value[:factor].to_f, modifier: log ? "ln2p" : nil}}
          end

        {
          filter: {
            exists: {
              field: field
            }
          }
        }.merge(script_score)
      end
    end

    def below12?
      below_version?("1.2.0")
    end

    def below14?
      below_version?("1.4.0")
    end

    def below_version?(version)
      Gem::Version.new(Searchkick.server_version) < Gem::Version.new(version)
    end
  end
end
