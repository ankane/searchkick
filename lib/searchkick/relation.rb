module Searchkick
  class Relation
    NO_DEFAULT_VALUE = Object.new

    # note: modifying body directly is not supported
    # and has no impact on query after being executed
    # TODO freeze body object?
    delegate :body, :params, to: :query
    delegate_missing_to :private_execute

    def initialize(model, term = "*", **options)
      @model = model
      @term = term
      @options = options

      # generate query to validate options
      query
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

    def offset(value = NO_DEFAULT_VALUE)
      # TODO remove in Searchkick 6
      if value == NO_DEFAULT_VALUE
        private_execute.offset
      else
        clone.offset!(value)
      end
    end

    def offset!(value)
      check_loaded
      @options[:offset] = value
      self
    end

    def page(value)
      clone.page!(value)
    end

    def page!(value)
      check_loaded
      @options[:page] = value
      self
    end

    def per_page(value = NO_DEFAULT_VALUE)
      # TODO remove in Searchkick 6
      if value == NO_DEFAULT_VALUE
        private_execute.per_page
      else
        clone.per_page!(value)
      end
    end

    def per_page!(value)
      check_loaded
      @options[:per_page] = value
      self
    end

    def only(*keys)
      Relation.new(@model, @term, **@options.slice(*keys))
    end

    def except(*keys)
      Relation.new(@model, @term, **@options.except(*keys))
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

      # reset query since options will change
      @query = nil
    end
  end
end
