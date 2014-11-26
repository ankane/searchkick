module Searchkick
  module Reindex

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

    def self.extended(klass)
      @descendents ||= []
      @descendents << klass unless @descendents.include?(klass)
    end

    def searchkick_import(options = {})
      index = options[:index] || searchkick_index
      batch_size = searchkick_options[:batch_size] || 1000

      # use scope for import
      scope = searchkick_klass
      scope = scope.search_import if scope.respond_to?(:search_import)
      if scope.respond_to?(:find_in_batches)
        scope.find_in_batches batch_size: batch_size do |batch|
          index.import batch.select{|item| item.should_index? }
        end
      else
        # https://github.com/karmi/tire/blob/master/lib/tire/model/import.rb
        # use cursor for Mongoid
        items = []
        scope.all.each do |item|
          items << item if item.should_index?
          if items.length == batch_size
            index.import items
            items = []
          end
        end
        index.import items
      end
    end

    def searchkick_create_index
      searchkick_index.create_index
    end

    def searchkick_index_options
      searchkick_index.index_options
    end

  end
end
