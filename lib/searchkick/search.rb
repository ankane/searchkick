module Searchkick
  # can't check mapping for conversions since the new index may not be built
  module Search
    def index_types
      Hash[ (((Product.index.mapping || {})["product"] || {})["properties"] || {}).map{|k, v| [k, v["type"]] } ].reject{|k, v| k == "conversions" || k[0] == "_" }
    end

    def search(term, options = {})
      fields = options[:fields] || ["_all"]
      tire.search do
        query do
          boolean do
            must do
              dis_max do
                query do
                  match fields, term, boost: 10, operator: "and", analyzer: "searchkick_search"
                end
                query do
                  match fields, term, boost: 10, operator: "and", analyzer: "searchkick_search2"
                end
                query do
                  match fields, term, use_dis_max: false, fuzziness: 0.7, max_expansions: 1, prefix_length: 1, operator: "and", analyzer: "searchkick_search"
                end
                query do
                  match fields, term, use_dis_max: false, fuzziness: 0.7, max_expansions: 1, prefix_length: 1, operator: "and", analyzer: "searchkick_search2"
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
        size options[:limit] if options[:limit]
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
        (options[:where] || {}).each do |field, value|
          if field == :or
            value.each do |or_clause|
              filter :or, or_clause.map{|or_statement| {term: or_statement} }
            end
          else
            # expand ranges
            if value.is_a?(Range)
              value = {gte: value.first, (value.exclude_end? ? :lt : :lte) => value.last}
            end

            if value.is_a?(Array) # in query
              filter :terms, {field => value}
            elsif value.is_a?(Hash)
              value.each do |op, op_value|
                if op == :not
                  if op_value.is_a?(Array)
                    filter :not, {terms: {field => op_value}}
                  else
                    filter :not, {term: {field => op_value}}
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
                  filter :range, field => range_query
                end
              end
            else
              filter :term, {field => value}
            end
          end
        end
        (options[:facets] || []).each do |field|
          facet field do
            terms field
          end
        end
      end
    end
  end
end
