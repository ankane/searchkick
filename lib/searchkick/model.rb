module Searchkick
  module Model

    def searchkick(options = {})
      class_eval do
        cattr_reader :searchkick_options, :searchkick_env, :searchkick_klass

        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_env, ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
        class_variable_set :@@searchkick_klass, self
        class_variable_set :@@searchkick_callbacks, options[:callbacks] != false
        class_variable_set :@@searchkick_index, options[:index_name] || [options[:index_prefix], model_name.plural, searchkick_env].compact.join("_")

        def self.searchkick_index
          index = class_variable_get :@@searchkick_index
          index = index.call if index.respond_to? :call
          Searchkick::Index.new(index)
        end

        extend Searchkick::Search
        extend Searchkick::Reindex
        include Searchkick::Similar

        if respond_to?(:after_commit)
          after_commit :reindex, if: proc{ self.class.search_callbacks? }
        else
          after_save :reindex, if: proc{ self.class.search_callbacks? }
          after_destroy :reindex, if: proc{ self.class.search_callbacks? }
        end

        def self.enable_search_callbacks
          class_variable_set :@@searchkick_callbacks, true
        end

        def self.disable_search_callbacks
          class_variable_set :@@searchkick_callbacks, false
        end

        def self.search_callbacks?
          class_variable_get(:@@searchkick_callbacks) && Searchkick.callbacks?
        end

        def should_index?
          true
        end

        def reindex
          index = self.class.searchkick_index
          if destroyed? or !should_index?
            begin
              index.remove self
            rescue Elasticsearch::Transport::Transport::Errors::NotFound
              # do nothing
            end
          else
            index.store self
          end
        end

        def search_data
          respond_to?(:to_hash) ? to_hash : serializable_hash
        end

        def as_indexed_json
          source = search_data

          # stringify fields
          source = source.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo}

          # Mongoid 4 hack
          if defined?(BSON::ObjectId) and source["_id"].is_a?(BSON::ObjectId)
            source["_id"] = source["_id"].to_s
          end

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

          source.as_json
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
