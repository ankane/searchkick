module Searchkick
  # can't check mapping for conversions since the new index may not be built
  module Search
    def index_types
      Hash[ (((Product.index.mapping || {})["product"] || {})["properties"] || {}).map{|k, v| [k, v["type"]] } ].reject{|k, v| k == "conversions" || k[0] == "_" }
    end

    def search(term, options = {})
      term = term.to_s
      fields = options[:fields] || ["_all"]
      operator = options[:partial] ? "or" : "and"
      collection =
        tire.search load: true do
          query do
            boolean do
              must do
                # TODO escape field
                score_script = options[:boost] ? "_score * log(doc['#{options[:boost]}'].value + 2.718281828)" : "_score"
                custom_score script: score_script do
                  dis_max do
                    query do
                      match fields, term, boost: 10, operator: operator, analyzer: "searchkick_search"
                    end
                    query do
                      match fields, term, boost: 10, operator: operator, analyzer: "searchkick_search2"
                    end
                    query do
                      match fields, term, use_dis_max: false, fuzziness: 0.7, max_expansions: 1, prefix_length: 1, operator: operator, analyzer: "searchkick_search"
                    end
                    query do
                      match fields, term, use_dis_max: false, fuzziness: 0.7, max_expansions: 1, prefix_length: 1, operator: operator, analyzer: "searchkick_search2"
                    end
                  end
                end
              end
              if options[:conversions]
                should do
                  nested path: "conversions", score_mode: "total" do
                    query do
                      custom_score script: "log(doc['count'].value)" do
                        match "query", term
                      end
                    end
                  end
                end
              end
            end
          end
          # fields "_id", "_type", "name" # only return _id and _type - http://www.elasticsearch.org/guide/reference/api/search/fields/
          size options[:limit] || 100000 # return all - like sql query
          from options[:offset] if options[:offset]
          explain options[:explain] if options[:explain]

          # order
          if options[:order]
            sort do
              options[:order].each do |k, v|
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

      collection.each_with_hit do |model, hit|
        model._score = hit["_score"]
      end
      collection
    end
  end
end
