module Searchkick
  module Search

    def search(term, options = {})
      term = term.to_s
      fields =
        if options[:fields]
          if options[:typeahead]
            options[:fields].map{|f| "#{f}.typeahead" }
          else
            options[:fields].map{|f| "#{f}.analyzed" }
          end
        else
          if options[:typeahead]
            (@searchkick_options[:typeahead] || []).map{|f| "#{f}.typeahead" }
          else
            ["_all"]
          end
        end
      operator = options[:partial] ? "or" : "and"
      load = options[:load].nil? ? true : options[:load]
      load = (options[:include] ? {include: options[:include]} : true) if load
      page = options.has_key?(:page) ? [options[:page].to_i, 1].max : nil
      tire_options = {
        load: load,
        page: page,
        per_page: options[:limit] || options[:per_page] || 100000 # return all
      }
      tire_options[:index] = options[:index_name] if options[:index_name]

      collection =
        tire.search tire_options do
          query do
            custom_filters_score do
              query do
                boolean do
                  must do
                    if options[:typeahead]
                      match fields, term, analyzer: "searchkick_typeahead_search"
                    else
                      dis_max do
                        query do
                          match fields, term, boost: 10, operator: operator, analyzer: "searchkick_search"
                        end
                        query do
                          match fields, term, boost: 10, operator: operator, analyzer: "searchkick_search2"
                        end
                        query do
                          match fields, term, use_dis_max: false, fuzziness: 1, max_expansions: 1, operator: operator, analyzer: "searchkick_search"
                        end
                        query do
                          match fields, term, use_dis_max: false, fuzziness: 1, max_expansions: 1, operator: operator, analyzer: "searchkick_search2"
                        end
                      end
                    end
                  end
                  unless options[:conversions] == false
                    should do
                      nested path: "conversions", score_mode: "total" do
                        query do
                          custom_score script: "doc['count'].value" do
                            match "query", term
                          end
                        end
                      end
                    end
                  end
                end
              end
              if options[:boost]
                filter do
                  filter :exists, field: options[:boost]
                  script "log(doc['#{options[:boost]}'].value + 2.718281828)"
                end
              end
              if options[:user_id]
                filter do
                  filter :term, user_ids: options[:user_id]
                  boost 100
                end
              end
              score_mode "total"
            end
          end
          from options[:offset] if options[:offset]
          explain options[:explain] if options[:explain]

          # order
          if options[:order]
            order = options[:order].is_a?(Enumerable) ? options[:order] : {options[:order] => :asc}
            sort do
              order.each do |k, v|
                by k, v
              end
            end
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

          where_filters.call(options[:where]).each do |f|
            type, value = f.first
            filter type, value
          end

          # facets
          if options[:facets]
            facets = options[:facets] || {}
            if facets.is_a?(Array) # convert to more advanced syntax
              facets = Hash[ facets.map{|f| [f, {}] } ]
            end

            facets.each do |field, facet_options|
              facet_filters = where_filters.call(facet_options[:where])
              facet field do
                terms field
                if facet_filters.size == 1
                  type, value = facet_filters.first.first
                  facet_filter type, value
                elsif facet_filters.size > 1
                  facet_filter :and, *facet_filters
                end
              end
            end
          end
        end

      collection
    end

  end
end
