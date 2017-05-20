module Searchkick
  module BatchExtensions
    def reindex(*args, &block)
      @relation.to_enum(:in_batches, of: @of, start: @start, finish: @finish, load: false).each do |relation|
        relation.reindex(*args, &block)
      end
    end
  end
end
