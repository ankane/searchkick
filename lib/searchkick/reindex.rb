module Searchkick
  module Reindex

    def self.extended(klass)
      @descendents ||= []
      @descendents << klass unless @descendents.include?(klass)
    end

    def reindex(options = {})
      searchkick_index.reindex_scope(searchkick_klass, options)
    end

    def clean_indices
      searchkick_index.clean_indices
    end

    def searchkick_import(options = {})
      (options[:index] || searchkick_index).import_scope(searchkick_klass)
    end

    def searchkick_create_index
      searchkick_index.create_index
    end

    def searchkick_index_options
      searchkick_index.index_options
    end

  end
end
