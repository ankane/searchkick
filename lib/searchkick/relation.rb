module Searchkick
  class Relation
    extend Forwardable

    attr_reader :klass, :term, :options

    def_delegators :execute, :map, :each, :any?, :empty?, :size, :length, :slice, :[], :to_ary,
      :records, :results, :suggestions, :each_with_hit, :with_details, :aggregations, :aggs,
      :took, :error, :model_name, :entry_name, :total_count, :total_entries,
      :current_page, :per_page, :limit_value, :total_pages, :num_pages,
      :offset_value, :previous_page, :prev_page, :next_page, :first_page?, :last_page?,
      :out_of_range?, :hits, :response, :to_a, :first, :scroll

    def initialize(klass, term = "*", **options)
      unknown_keywords = options.keys - [:aggs, :block, :body, :body_options, :boost,
        :boost_by, :boost_by_distance, :boost_by_recency, :boost_where, :conversions, :conversions_term, :debug, :emoji, :exclude, :execute, :explain,
        :fields, :highlight, :includes, :index_name, :indices_boost, :limit, :load,
        :match, :misspellings, :models, :model_includes, :offset, :operator, :order, :padding, :page, :per_page, :profile,
        :request_params, :routing, :scope_results, :scroll, :select, :similar, :smart_aggs, :suggest, :total_entries, :track, :type, :where]
      raise ArgumentError, "unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?

      @klass = klass
      @term = term
      @options = options
    end

    def where(opts)
      spawn.where!(opts)
    end

    def where!(opts)
      opts = sanitize_opts(opts)

      if options[:where]
        options[:where] = [{_and: [options[:where], opts]}]
      else
        options[:where] = opts
      end
      self
    end

    def limit(value)
      spawn.limit!(value)
    end

    def limit!(value)
      options[:limit] = value
      self
    end

    def offset(value)
      spawn.offset!(value)
    end

    def offset!(value)
      options[:offset] = value
      self
    end

    def order(*args)
      spawn.order!(*args)
    end

    def order!(*args)
      options[:order] = Array(options[:order]) + args
      self
    end

    def select(*fields, &block)
      if block_given?
        # TODO better error message
        raise ArgumentError, "too many arguments" if fields.any?
        records.select(&block)
      else
        spawn.select!(*fields)
      end
    end

    # TODO decide how to handle block form
    def select!(*fields)
      options[:select] = Array(options[:select]) + fields
      self
    end

    def page(value)
      spawn.page!(value)
    end

    def page!(value)
      options[:page] = value
      self
    end

    def per_page(value)
      spawn.per_page!(value)
    end

    def per_page!(value)
      options[:per_page] = value
      self
    end

    def padding(value)
      spawn.padding!(value)
    end

    def padding!(value)
      options[:padding] = value
      self
    end

    def fields(*fields)
      spawn.fields!(*fields)
    end

    def fields!(*fields)
      options[:fields] = Array(options[:fields]) + fields
      self
    end

    def load(value)
      spawn.load!(value)
    end

    def load!(value)
      options[:load] = value
      self
    end

    def includes(*args)
      spawn.includes!(*args)
    end

    def includes!(*args)
      options[:includes] = Array(options[:includes]) + args
      self
    end

    def models(*args)
      spawn.models!(*args)
    end

    def models!(*args)
      options[:models] = Array(options[:models]) + args
      self
    end

    def model_includes(value)
      spawn.model_includes!(value)
    end

    def model_includes!(value)
      options[:model_includes] ||= {}
      value.each do |k, v|
        options[:model_includes][k] = Array(options[:model_includes][k]) + v
      end
      self
    end

    # same as Active Record
    def inspect
      entries = results.first(11).map!(&:inspect)
      entries[10] = "..." if entries.size == 11
      "#<#{self.class.name} [#{entries.join(', ')}]>"
    end

    private

    def sanitize_opts(attributes)
      if attributes.respond_to?(:permitted?)
        raise ActiveModel::ForbiddenAttributesError if !attributes.permitted?
        attributes.to_h
      else
        attributes
      end
    end

    # TODO reset when ! methods called
    def execute
      @execute ||= Query.new(klass, term, options).execute
    end

    def spawn
      Relation.new(klass, term, options.deep_dup)
    end
  end
end
