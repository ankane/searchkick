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
        (options[:where] || {}).each do |k, v|
          if k == :or
            filter :or, v.map{|v2| {term: v2} }
          else
            if v.is_a?(Range)
              v = {gte: v.first, (v.exclude_end? ? :lt : :lte) => v.last}
            end

            if v.is_a?(Array)
              filter :terms, {k => v}
            elsif v.is_a?(Hash)
              v.each do |k2, v2|
                if k2 == :not
                  if v2.is_a?(Array)
                    filter :not, {terms: {k => v2}}
                  else
                    filter :not, {term: {k => v2}}
                  end
                else
                  opts =
                    case k2
                    when :gt
                      {from: v2, include_lower: false}
                    when :gte
                      {from: v2, include_lower: true}
                    when :lt
                      {to: v2, include_upper: false}
                    when :lte
                      {to: v2, include_upper: true}
                    else
                      raise "Unknown where operator"
                    end
                  filter :range, k => opts
                end
              end
            else
              filter :term, {k => v}
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
