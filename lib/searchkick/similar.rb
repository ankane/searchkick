module Searchkick
  module Similar
    def similar(options = {})
      like_text = index.retrieve(document_type, id).to_hash
        .keep_if{|k,v| k[0] != "_" and (!options[:fields] or options[:fields].map(&:to_sym).include?(k)) }
        .values.compact.join(" ")

      fields = options[:fields] ? options[:fields].map{|f| "#{f}.analyzed" } : ["_all"]

      payload = {
        query: {
          more_like_this: {
            fields: fields,
            like_text: like_text,
            min_doc_freq: 1,
            min_term_freq: 1
          }
        },
        filter: {
          not: {
            term: {
              _id: id
            }
          }
        }
      }

      search = Tire::Search::Search.new(index_name, payload: payload)
      Searchkick::Results.new(search.json, search.options)
    end
  end
end
