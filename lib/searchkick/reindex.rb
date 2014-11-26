module Searchkick
  module Reindex

    def self.extended(klass)
      @descendents ||= []
      @descendents << klass unless @descendents.include?(klass)
    end

    # https://gist.github.com/jarosan/3124884
    # http://www.elasticsearch.org/blog/changing-mapping-with-zero-downtime/
    def reindex(options = {})
      skip_import = options[:import] == false

      clean_indices

      index = searchkick_create_index

      # check if alias exists
      if searchkick_index.alias_exists?
        # import before swap
        searchkick_import(index: index) unless skip_import

        # get existing indices to remove
        searchkick_index.swap(index.name)
        clean_indices
      else
        searchkick_index.delete if searchkick_index.exists?
        searchkick_index.swap(index.name)

        # import after swap
        searchkick_import(index: index) unless skip_import
      end

      index.refresh

      true
    end

    def clean_indices
      searchkick_index.clean_indices
    end

    def searchkick_import(options = {})
      index = options[:index] || searchkick_index
      index.import_scope(searchkick_klass)
    end

    def searchkick_create_index
      searchkick_index.create_index
    end

    def searchkick_index_options
      searchkick_index.index_options
    end

  end
end
