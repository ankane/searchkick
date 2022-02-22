module Searchkick
  class Relation
    # note: modifying body directly is not supported
    # and has no impact on query after being executed
    # TODO freeze body object?
    delegate :body, :params, to: :@query
    delegate_missing_to :private_execute

    def initialize(model, term = "*", **options)
      @query = Query.new(model, term, **options)
    end

    # same as Active Record
    def inspect
      entries = results.first(11).map!(&:inspect)
      entries[10] = "..." if entries.size == 11
      "#<#{self.class.name} [#{entries.join(', ')}]>"
    end

    def execute
      Searchkick.warn("The execute method is no longer needed")
      private_execute
      self
    end

    private

    def private_execute
      @execute ||= @query.execute
    end

    def query
      @query
    end
  end
end
