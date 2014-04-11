module Searchkick
  module Similar

    def similar(options = {})
      like_text = self.class.searchkick_index.retrieve(self).to_hash
        .keep_if{|k,v| !options[:fields] || options[:fields].map(&:to_s).include?(k) }
        .values.compact.join(" ")

      # TODO deep merge method
      options[:where] ||= {}
      options[:where][:_id] ||= {}
      options[:where][:_id][:not] = id.to_s
      options[:limit] ||= 10
      options[:similar] = true
      self.class.send(Searchkick.search_method_name, like_text, options)
    end

  end
end
