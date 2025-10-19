module Searchkick
  class Relation
    NO_DEFAULT_VALUE = Object.new

    # note: modifying body directly is not supported
    # and has no impact on query after being executed
    # TODO freeze body object?
    delegate :params, to: :query
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
    def aggs(value = NO_DEFAULT_VALUE)
      if value == NO_DEFAULT_VALUE
        private_execute.aggs
      else
        clone.aggs!(value)
      end
    end

    # experimental
    def aggs!(value)
      check_loaded
      (@options[:aggs] ||= {}).merge!(value)
      self
    end

    # experimental
    def body(value = NO_DEFAULT_VALUE)
      if value == NO_DEFAULT_VALUE
        query.body
      else
        clone.body!(value)
      end
    end

    # experimental
    def body!(value)
      check_loaded
      @options[:body] = value
      self
    end

    # experimental
    def body_options(value)
      clone.body_options!(value)
    end

    # experimental
    def body_options!(value)
      check_loaded
      (@options[:body_options] ||= {}).merge!(value)
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
    def conversions(value)
      clone.conversions!(value)
    end

    # experimental
    def conversions!(value)
      check_loaded
      @options[:conversions] = value
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
    def conversions_term(value)
      clone.conversions_term!(value)
    end

    # experimental
    def conversions_term!(value)
      check_loaded
      @options[:conversions_term] = value
      self
    end

    # experimental
    def debug(value = true)
      clone.debug!(value)
    end

    # experimental
    def debug!(value = true)
      check_loaded
      @options[:debug] = value
      self
    end

    # experimental
    def emoji(value = true)
      clone.emoji!(value)
    end

    # experimental
    def emoji!(value = true)
      check_loaded
      @options[:emoji] = value
      self
    end

    # experimental
    def exclude(*values)
      clone.exclude!(*values)
    end

    # experimental
    def exclude!(*values)
      check_loaded
      (@options[:exclude] ||= []).concat(values.flatten)
      self
    end

    # experimental
    def explain(value = true)
      clone.explain!(value)
    end

    # experimental
    def explain!(value = true)
      check_loaded
      @options[:explain] = value
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

    # highlight
    def highlight(value)
      clone.highlight!(value)
    end

    # experimental
    def highlight!(value)
      check_loaded
      @options[:highlight] = value
      self
    end

    # experimental
    def includes(*values)
      clone.includes!(*values)
    end

    # experimental
    def includes!(*values)
      check_loaded
      (@options[:includes] ||= []).concat(values.flatten)
      self
    end

    # experimental
    def index_name(*values)
      clone.index_name!(*values)
    end

    # experimental
    def index_name!(*values)
      check_loaded
      values = values.flatten
      if values.all? { |v| v.respond_to?(:searchkick_index) }
        models!(*values)
      else
        (@options[:index_name] ||= []).concat(values)
        self
      end
    end

    # experimental
    def indices_boost(value)
      clone.indices_boost!(value)
    end

    # experimental
    def indices_boost!(value)
      check_loaded
      (@options[:indices_boost] ||= {}).merge!(value)
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
    def load(value = NO_DEFAULT_VALUE)
      if value == NO_DEFAULT_VALUE
        private_execute
        self
      else
        clone.load!(value)
      end
    end

    # experimental
    def load!(value)
      check_loaded
      @options[:load] = value
      self
    end

    # experimental
    def match(value)
      clone.match!(value)
    end

    # experimental
    def match!(value)
      check_loaded
      @options[:match] = value
      self
    end

    # experimental
    def misspellings(value)
      clone.misspellings!(value)
    end

    # experimental
    def misspellings!(value)
      check_loaded
      @options[:misspellings] = value
      self
    end

    # experimental
    def models(*values)
      clone.models!(*values)
    end

    # experimental
    def models!(*values)
      check_loaded
      (@options[:models] ||= []).concat(values.flatten)
      self
    end

    # experimental
    def model_includes(*values)
      clone.model_includes!(*values)
    end

    # experimental
    def model_includes!(*values)
      check_loaded
      (@options[:model_includes] ||= []).concat(values.flatten)
      self
    end

    # experimental
    def offset(value = NO_DEFAULT_VALUE)
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
    def opaque_id(value)
      clone.opaque_id!(value)
    end

    # experimental
    def opaque_id!(value)
      check_loaded
      @options[:opaque_id] = value
      self
    end

    # experimental
    def operator(value)
      clone.operator!(value)
    end

    # experimental
    def operator!(value)
      check_loaded
      @options[:operator] = value
      self
    end

    # experimental
    def order(*values)
      clone.order!(*values)
    end

    # experimental
    def order!(*values)
      check_loaded
      (@options[:order] ||= []).concat(values.flatten)
      self
    end

    # experimental
    def padding(value = NO_DEFAULT_VALUE)
      if value == NO_DEFAULT_VALUE
        private_execute.padding
      else
        clone.padding!(value)
      end
    end

    # experimental
    def padding!(value)
      check_loaded
      @options[:padding] = value
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
    def profile(value = true)
      clone.profile!(value)
    end

    # experimental
    def profile!(value = true)
      check_loaded
      @options[:profile] = value
      self
    end

    # experimental
    def request_params(value)
      clone.request_params!(value)
    end

    # experimental
    def request_params!(value)
      check_loaded
      (@options[:request_params] ||= {}).merge!(value)
      self
    end

    # experimental
    def routing(value)
      clone.routing!(value)
    end

    # experimental
    def routing!(value)
      check_loaded
      @options[:routing] = value
      self
    end

    # experimental
    def scope_results(value)
      clone.scope_results!(value)
    end

    # experimental
    def scope_results!(value)
      check_loaded
      @options[:scope_results] = value
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
      (@options[:select] ||= []).concat(values.flatten)
      self
    end

    # experimental
    def similar(value = true)
      clone.similar!(value)
    end

    # experimental
    def similar!(value = true)
      check_loaded
      @options[:similar] = value
      self
    end

    # experimental
    def smart_aggs(value)
      clone.smart_aggs!(value)
    end

    # experimental
    def smart_aggs!(value)
      check_loaded
      @options[:smart_aggs] = value
      self
    end

    # experimental
    def suggest(value = true)
      clone.suggest!(value)
    end

    # experimental
    def suggest!(value = true)
      check_loaded
      @options[:suggest] = value
      self
    end

    # experimental
    def total_entries(value = NO_DEFAULT_VALUE)
      if value == NO_DEFAULT_VALUE
        private_execute.total_entries
      else
        clone.total_entries!(value)
      end
    end

    # experimental
    def total_entries!(value)
      check_loaded
      @options[:total_entries] = value
      self
    end

    # experimental
    def track(value = true)
      clone.track!(value)
    end

    # experimental
    def track!(value = true)
      check_loaded
      @options[:track] = value
      self
    end

    # experimental
    def type(*values)
      clone.type!(*values)
    end

    # experimental
    def type!(*values)
      check_loaded
      (@options[:type] ||= []).concat(values.flatten)
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
    def only(*keys)
      Relation.new(@model, @term, **@options.slice(*keys))
    end

    # experimental
    def except(*keys)
      Relation.new(@model, @term, **@options.except(*keys))
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
