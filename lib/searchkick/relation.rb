module Searchkick
  class Relation
    NO_DEFAULT_VALUE = Object.new

    # note: modifying body directly is not supported
    # and has no impact on query after being executed
    # TODO freeze body object?
    delegate :body, :params, to: :query
    delegate_missing_to :private_execute

    attr_reader :model
    alias_method :klass, :model

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

    # experimental
    def limit(value)
      clone.limit!(value)
    end

    # experimental
    def limit!(value)
      check_loaded
      @options[:limit] = value
      self
    end

    # experimental
    def offset(value = NO_DEFAULT_VALUE)
      # TODO remove in Searchkick 6
      if value == NO_DEFAULT_VALUE
        private_execute.offset
      else
        clone.offset!(value)
      end
    end

    # experimental
    def offset!(value)
      check_loaded
      @options[:offset] = value
      self
    end

    # experimental
    def page(value)
      clone.page!(value)
    end

    # experimental
    def page!(value)
      check_loaded
      @options[:page] = value
      self
    end

    # experimental
    def per_page(value = NO_DEFAULT_VALUE)
      # TODO remove in Searchkick 6
      if value == NO_DEFAULT_VALUE
        private_execute.per_page
      else
        clone.per_page!(value)
      end
    end

    # experimental
    def per_page!(value)
      check_loaded
      @options[:per_page] = value
      self
    end

    # experimental
    def where(value = NO_DEFAULT_VALUE)
      if value == NO_DEFAULT_VALUE
        Where.new(self)
      else
        clone.where!(value)
      end
    end

    # experimental
    def where!(value)
      check_loaded
      if @options[:where]
        @options[:where] = {_and: [@options[:where], ensure_permitted(value)]}
      else
        @options[:where] = ensure_permitted(value)
      end
      self
    end

    # experimental
    def rewhere(value)
      clone.rewhere!(value)
    end

    # experimental
    def rewhere!(value)
      check_loaded
      @options[:where] = ensure_permitted(value)
      self
    end

    # experimental
    def order(*values)
      clone.order!(*values)
    end

    # experimental
    def order!(*values)
      values = values.first if values.size == 1 && values.first.is_a?(Array)
      check_loaded
      (@options[:order] ||= []).concat(values)
      self
    end

    # experimental
    def reorder(*values)
      clone.reorder!(*values)
    end

    # experimental
    def reorder!(*values)
      check_loaded
      @options[:order] = values
      self
    end

    # experimental
    def select(*values, &block)
      if block_given?
        private_execute.select(*values, &block)
      else
        clone.select!(*values)
      end
    end

    # experimental
    def select!(*values)
      check_loaded
      (@options[:select] ||= []).concat(values)
      self
    end

    # experimental
    def reselect(*values)
      clone.reselect!(*values)
    end

    # experimental
    def reselect!(*values)
      check_loaded
      @options[:select] = values
      self
    end

    # experimental
    def includes(*values)
      clone.includes!(*values)
    end

    # experimental
    def includes!(*values)
      check_loaded
      (@options[:includes] ||= []).concat(values)
      self
    end

    # experimental
    def fields(*values)
      clone.fields!(*values)
    end

    # experimental
    def fields!(*values)
      check_loaded
      (@options[:fields] ||= []).concat(values.flatten)
      self
    end

    # experimental
    def boost(value)
      clone.boost!(value)
    end

    # experimental
    def boost!(value)
      check_loaded
      @options[:boost] = value
      self
    end

    # experimental
    def boost_by(value)
      clone.boost_by!(value)
    end

    # experimental
    def boost_by!(value)
      check_loaded
      if value.is_a?(Array)
        value = value.to_h { |f| [f, {factor: 1}] }
      elsif !value.is_a?(Hash)
        value = {value => {factor: 1}}
      end
      (@options[:boost_by] ||= {}).merge!(value)
      self
    end

    # experimental
    def boost_where(value)
      clone.boost_where!(value)
    end

    # experimental
    def boost_where!(value)
      check_loaded
      # TODO merge duplicate fields
      (@options[:boost_where] ||= {}).merge!(value)
      self
    end

    # experimental
    def boost_by_recency(value)
      clone.boost_by_recency!(value)
    end

    # experimental
    def boost_by_recency!(value)
      check_loaded
      (@options[:boost_by_recency] ||= {}).merge!(value)
      self
    end

    # experimental
    def boost_by_distance(value)
      clone.boost_by_distance!(value)
    end

    # experimental
    def boost_by_distance!(value)
      check_loaded
      # legacy format
      value = {value[:field] => value.except(:field)} if value[:field]
      (@options[:boost_by_distance] ||= {}).merge!(value)
      self
    end

    # experimental
    def boost_indices(value)
      clone.boost_indices!(value)
    end
    alias_method :indices_boost, :boost_indices

    # experimental
    def boost_indices!(value)
      check_loaded
      (@options[:indices_boost] ||= {}).merge!(value)
      self
    end
    alias_method :indices_boost!, :boost_indices!

    # experimental
    def models(value)
      clone.models!(value)
    end

    # experimental
    def models!(*values)
      check_loaded
      (@options[:models] ||= []).concat(values.flatten)
      self
    end

    # experimental
    def conversions_v1(value)
      clone.conversions_v1!(value)
    end

    # experimental
    def conversions_v1!(value)
      check_loaded
      @options[:conversions_v1] = value
      self
    end

    # experimental
    def conversions_v2(value)
      clone.conversions_v2!(value)
    end

    # experimental
    def conversions_v2!(value)
      check_loaded
      @options[:conversions_v2] = value
      self
    end

    # experimental
    def knn(value)
      clone.knn!(value)
    end

    # experimental
    def knn!(value)
      check_loaded
      @options[:knn] = value
      self
    end

    # experimental
    def only(*keys)
      Relation.new(@model, @term, **@options.slice(*keys))
    end

    # experimental
    def except(*keys)
      Relation.new(@model, @term, **@options.except(*keys))
    end

    # experimental
    def load
      private_execute
      self
    end

    def loaded?
      !@execute.nil?
    end

    undef_method :respond_to_missing?

    def respond_to_missing?(...)
      Results.new(nil, nil, nil).respond_to?(...) || super
    end

    def to_yaml
      private_execute.to_a.to_yaml
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

    # provides *very* basic protection from unfiltered parameters
    # this is not meant to be comprehensive and may be expanded in the future
    def ensure_permitted(obj)
      obj.to_h
    end

    def initialize_copy(other)
      super
      @execute = nil
    end
  end
end
