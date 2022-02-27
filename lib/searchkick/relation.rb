module Searchkick
  class Relation
    # note: modifying body directly is not supported
    # and has no impact on query after being executed
    # TODO freeze body object?
    delegate :body, :params, to: :query
    delegate_missing_to :private_execute

    def initialize(model, term = "*", **options)
      @model = model
      @term = term
      @options = options
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

    def limit(value)
      clone.limit!(value)
    end

    def limit!(value)
      check_loaded
      @options[:limit] = value
      self
    end

    def loaded?
      !@execute.nil?
    end

    private

    def private_execute
      @execute ||= query.execute
    end

    def query
      @query ||= Query.new(@model, @term, **@options)
    end

    def check_loaded
      raise Error, "Relation loaded" if loaded?
    end
  end
end
