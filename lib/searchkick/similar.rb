module Searchkick
  module Similar

    def similar(options = {})
      like_text = self.class.searchkick_index.retrieve(document_type, id).to_hash
        .keep_if{|k,v| k[0] != "_" and (!options[:fields] or options[:fields].map(&:to_sym).include?(k)) }
        .values.compact.join(" ")

      # TODO deep merge method
      options[:where] ||= {}
      options[:where][:_id] ||= {}
      options[:where][:_id][:not] = id.to_s
      options[:limit] ||= 10
      options[:similar] = true
      self.class.search(like_text, options)
    end

  end
end
