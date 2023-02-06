module Searchkick
  module Utils
    # private
    def self.check_reindex_options(mode:, method_name:, allow_missing:)
      if allow_missing
        if !method_name
          raise Error, "allow_missing requires partial reindexing"
        elsif mode != :inline && mode != true
          raise Error, "allow_missing only available with :inline mode"
        end
      end
    end
  end
end
