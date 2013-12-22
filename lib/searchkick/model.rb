module Searchkick
  module Model

    def searchkick(options = {})
      class_eval do
        cattr_reader :searchkick_options, :searchkick_env, :searchkick_klass,
                     :searchkick_index

        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_env, ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
        class_variable_set :@@searchkick_klass, self
        class_variable_set :@@searchkick_enabled, false

        # set index name
        # TODO support proc
        index_name = options[:index_name] || [options[:index_prefix], model_name.plural, searchkick_env].compact.join("_")
        class_variable_set :@@searchkick_index, Tire::Index.new(index_name)

        extend Searchkick::Search
        extend Searchkick::Reindex
        include Searchkick::Similar

        def self.searchkick_enable!
          unless class_variable_get(:@@searchkick_enabled)
            class_variable_set :@@searchkick_enabled, true
            after_save :reindex
            after_destroy :reindex
          end
        end

        def self.searchkick_disable!
          if class_variable_get(:@@searchkick_enabled)
            class_variable_set :@@searchkick_enabled, false
            skip_callback :save, :after, :reindex
            skip_callback :destroy, :after, :reindex
          end
        end

        def self.searchkick_enabled?
          !!class_variable_get(:@@searchkick_enabled) && Searchkick.enabled?
        end

        unless options[:callbacks] == false
          self.searchkick_enable!
        end

        def reindex
          if self.class.searchkick_enabled?
            index = self.class.searchkick_index
            if destroyed?
              index.remove self
            else
              index.store self
            end
          end
        end

        def search_data
          respond_to?(:to_hash) ? to_hash : serializable_hash
        end

        def to_indexed_json
          source = search_data

          # stringify fields
          source = source.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo}

          # Mongoid 4 hack
          source["_id"] = source["_id"].to_s if source["_id"]

          options = self.class.searchkick_options

          # conversions
          conversions_field = options[:conversions]
          if conversions_field and source[conversions_field]
            source[conversions_field] = source[conversions_field].map{|k, v| {query: k, count: v} }
          end

          # hack to prevent generator field doesn't exist error
          (options[:suggest] || []).map(&:to_s).each do |field|
            source[field] = nil if !source[field]
          end

          # locations
          (options[:locations] || []).map(&:to_s).each do |field|
            if source[field]
              if source[field].first.is_a?(Array) # array of arrays
                source[field] = source[field].map{|a| a.map(&:to_f).reverse }
              else
                source[field] = source[field].map(&:to_f).reverse
              end
            end
          end

          # change all BigDecimal values to floats due to
          # https://github.com/rails/rails/issues/6033
          # possible loss of precision :/
          cast_big_decimal =
            proc do |obj|
              case obj
              when BigDecimal
                obj.to_f
              when Hash
                obj.each do |k, v|
                  obj[k] = cast_big_decimal.call(v)
                end
              when Enumerable
                obj.map! do |v|
                  cast_big_decimal.call(v)
                end
              else
                obj
              end
            end

          cast_big_decimal.call(source)

          # p search_data

          source.to_json
        end

        # TODO remove

        def self.document_type
          model_name.to_s.underscore
        end

        def document_type
          self.class.document_type
        end

      end
    end

  end
end
