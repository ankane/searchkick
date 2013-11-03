module Searchkick
  module Model

    def searchkick(options = {})
      class_eval do
        cattr_reader :searchkick_options, :searchkick_env, :searchkick_klass, :searchkick_index

        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_env, ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
        class_variable_set :@@searchkick_klass, self

        # set index name
        # TODO support proc
        index_name = options[:index_name] || [options[:index_prefix], model_name.plural, searchkick_env].compact.join("_")
        class_variable_set :@@searchkick_index, Tire::Index.new(index_name)

        extend Searchkick::Search
        extend Searchkick::Reindex
        include Searchkick::Similar

        def reindex
          index = self.class.searchkick_index
          if destroyed?
            index.remove self
          else
            index.store self
          end
        end

        unless options[:callbacks] == false
          # TODO ability to temporarily disable
          after_save :reindex
          after_destroy :reindex
        end

        def search_data
          respond_to?(:to_hash) ? to_hash : serializable_hash
        end

        def to_indexed_json
          source = search_data

          # stringify fields
          source = source.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo}

          options = self.class.searchkick_options

          # conversions
          conversions_field = options[:conversions]
          if conversions_field and source[conversions_field]
            source[conversions_field] = source[conversions_field].map{|k, v| {query: k, count: v} }
          end

          # hack to prevent generator field doesn't exist error
          (options[:suggest] || []).map(&:to_s).each do |field|
            source[field] = "a" if !source[field]
          end

          # locations
          (options[:locations] || []).map(&:to_s).each do |field|
            source[field] = source[field].map(&:to_f).reverse if source[field]
          end

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
