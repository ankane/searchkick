module Searchkick
  class Relation
    extend Forwardable

    attr_reader :klass, :term, :options

    def_delegators :execute, :map, :each, :any?, :empty?, :size, :length, :slice, :[], :to_ary,
      :records, :results, :suggestions, :each_with_hit, :with_details, :aggregations,
      :took, :error, :model_name, :entry_name, :total_count, :total_entries,
      :current_page, :per_page, :limit_value, :total_pages, :num_pages,
      :offset_value, :previous_page, :prev_page, :next_page, :first_page?, :last_page?,
      :out_of_range?, :hits, :response, :to_a, :first, :highlights, :group_by, :misspellings?, :with_highlights,
      :none?, :one?, :many?

    def_delegators :query, :params

    def initialize(klass, term = "*", **options)
      unknown_keywords = options.keys - [:aggs, :block, :body, :body_options, :boost,
        :boost_by, :boost_by_distance, :boost_by_recency, :boost_where, :conversions, :conversions_term, :debug, :emoji, :exclude, :execute, :explain,
        :fields, :highlight, :includes, :index_name, :indices_boost, :limit, :load,
        :match, :misspellings, :models, :model_includes, :offset, :operator, :order, :padding, :page, :per_page, :profile,
        :request_params, :routing, :scope_results, :scroll, :select, :similar, :smart_aggs, :suggest, :total_entries, :track, :type, :where]
      raise ArgumentError, "unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?

      if options[:execute] == false
        Searchkick.warn("The execute option is deprecated")
        options.delete(:execute)
      end

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
        options[:where] = {_and: [options[:where], opts]}
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

    def offset(*args)
      if args.empty?
        execute.offset
      else
        spawn.offset!(*args)
      end
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

    def reorder(*args)
      spawn.reorder!(*args)
    end

    def reorder!(*args)
      options[:order] = args
      self
    end

    def none
      spawn.none!
    end

    def none!
      options[:limit] = 0 # TODO use where?
      self
    end

    def unscoped
      spawn.unscoped!
    end

    def unscoped!
      @options = {}
      self
    end

    # TODO support multiple
    def pluck(*fields)
      result = select(*fields).load(false)
      if fields.size == 1
        field = fields.first
        result.map { |v| v[field] }
      else
        result.map { |v| fields.map { |f| v[f] } }
      end
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
    # TODO see how Active Record merges multiple calls
    def select!(*fields)
      options[:select] = fields.size == 1 ? fields.first : fields
      self
    end

    def page(value)
      spawn.page!(value)
    end

    def page!(value)
      options[:page] = value
      self
    end

    def per_page(*args)
      if args.empty?
        execute.per_page
      else
        spawn.per_page!(*args)
      end
    end
    alias_method :per, :per_page

    def per_page!(value)
      options[:per_page] = value
      self
    end

    def padding(*args)
      if args.empty?
        execute.padding
      else
        spawn.padding!(*args)
      end
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
      if value.respond_to?(:call)
        options[:load] = true
        options[:scope_results] = value
      else
        options[:load] = value
      end
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

    def operator(value)
      spawn.operator!(value)
    end

    def operator!(value)
      options[:operator] = value
      self
    end

    # TODO support boost_by(:order, :other)
    def boost_by(value)
      spawn.boost_by!(value)
    end

    def boost_by!(value)
      options[:boost_by] = value
      self
    end

    def boost_where(value)
      spawn.boost_where!(value)
    end

    # TODO merge options
    def boost_where!(value)
      options[:boost_where] = value
      self
    end

    def boost_by_recency(value)
      spawn.boost_by_recency!(value)
    end

    # TODO merge options
    def boost_by_recency!(value)
      options[:boost_by_recency] = value
      self
    end

    def boost_by_distance(value)
      spawn.boost_by_distance!(value)
    end

    # TODO merge options
    def boost_by_distance!(value)
      options[:boost_by_distance] = value
      self
    end

    def indices_boost(value)
      spawn.indices_boost!(value)
    end

    # TODO merge options
    def indices_boost!(value)
      options[:indices_boost] = value
      self
    end

    def aggs(*args)
      if args.empty?
        execute.aggs
      else
        aggs!(*args)
      end
    end

    # TODO merge options
    def aggs!(*args)
      options[:aggs] = hash_args(options[:aggs], args)
      self
    end

    def match(value)
      spawn.match!(value)
    end

    def match!(value)
      options[:match] = value
      self
    end

    def highlight(value = true)
      spawn.highlight!(value)
    end

    def highlight!(value = true)
      options[:highlight] = value
      self
    end

    def scroll(value = nil, &block)
      spawn.scroll!(value, &block)
    end

    def scroll!(value = nil, &block)
      options[:scroll] = value if value
      if !value && !block
        execute.scroll
      elsif block
        execute.scroll(&block)
      else
        self
      end
    end

    def routing(value)
      spawn.routing!(value)
    end

    def routing!(value)
      options[:routing] = value
      self
    end

    def body(*args)
      if args.empty?
        query.body
      else
        spawn.body!(*args)
      end
    end

    def body!(value)
      options[:body] = value
      self
    end

    def body_options(value)
      spawn.body_options!(value)
    end

    def body_options!(value)
      options[:body_options] = value
      self
    end

    def request_params(value)
      spawn.request_params!(value)
    end

    def request_params!(value)
      options[:request_params] = value
      self
    end

    def debug(value = true)
      spawn.debug!(value)
    end

    def debug!(value = true)
      options[:debug] = value
      self
    end

    def explain(value = true)
      spawn.explain!(value)
    end

    def explain!(value = true)
      options[:explain] = value
      self
    end

    def exclude(*args)
      spawn.exclude!(*args)
    end

    def exclude!(*args)
      options[:exclude] = Array(options[:exclude]) + args.flatten
      self
    end

    def misspellings(value)
      spawn.misspellings!(value)
    end

    def misspellings!(value)
      options[:misspellings] = value
      self
    end

    def suggest(value = true)
      spawn.suggest!(value)
    end

    def suggest!(value = true)
      options[:suggest] = value
      self
    end

    def emoji(value = true)
      spawn.emoji!(value)
    end

    def emoji!(value = true)
      options[:emoji] = value
      self
    end

    def smart_aggs(value)
      spawn.smart_aggs!(value)
    end

    def smart_aggs!(value)
      options[:smart_aggs] = value
      self
    end

    def type(*args)
      spawn.type!(*args)
    end

    def type!(*args)
      options[:type] = Array(options[:type]) + args.flatten
      self
    end

    def conversions(value)
      spawn.conversions!(value)
    end

    def conversions!(value)
      options[:conversions] = value
      self
    end

    def conversions_term(value)
      spawn.conversions_term!(value)
    end

    def conversions_term!(value)
      options[:conversions_term] = value
      self
    end

    # same as Active Record
    def inspect
      entries = results.first(11).map!(&:inspect)
      entries[10] = "..." if entries.size == 11
      "#<#{self.class.name} [#{entries.join(', ')}]>"
    end

    # private
    def query
      @query ||= Query.new(klass, term, options)
    end

    # private
    # TODO reset when ! methods called
    def execute
      @execute ||= query.execute
    end

    private

    def hash_args(old, new)
      old ||= {}
      new.each do |v|
        if v.is_a?(Hash)
          old.merge!(v)
        else
          old[v] = {}
        end
      end
      old
    end

    def sanitize_opts(attributes)
      if attributes.respond_to?(:permitted?)
        raise ActiveModel::ForbiddenAttributesError if !attributes.permitted?
        attributes.to_h
      else
        attributes
      end
    end

    def spawn
      # cannot deep dup due to model classes
      Relation.new(klass, term, options.dup)
    end
  end
end
