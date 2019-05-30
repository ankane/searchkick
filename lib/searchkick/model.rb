module Searchkick
  module Model
    def searchkick(**options)
      options = Searchkick.model_options.merge(options)

      unknown_keywords = options.keys - [:_all, :_type, :batch_size, :callbacks, :case_sensitive, :conversions, :default_fields,
        :filterable, :geo_shape, :highlight, :ignore_above, :index_name, :index_prefix, :inheritance, :language,
        :locations, :mappings, :match, :merge_mappings, :routing, :searchable, :settings, :similarity,
        :special_characters, :stem, :stem_conversions, :suggest, :synonyms, :text_end,
        :text_middle, :text_start, :word, :wordnet, :word_end, :word_middle, :word_start]
      raise ArgumentError, "unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?

      raise "Only call searchkick once per model" if respond_to?(:searchkick_index)

      Searchkick.models << self

      options[:_type] ||= -> { searchkick_index.klass_document_type(self, true) }

      callbacks = options.key?(:callbacks) ? options[:callbacks] : :inline
      unless [:inline, true, false, :async, :queue].include?(callbacks)
        raise ArgumentError, "Invalid value for callbacks"
      end

      index_name =
        if options[:index_name]
          options[:index_name]
        elsif options[:index_prefix].respond_to?(:call)
          -> { [options[:index_prefix].call, model_name.plural, Searchkick.env, Searchkick.index_suffix].compact.join("_") }
        else
          [options.key?(:index_prefix) ? options[:index_prefix] : Searchkick.index_prefix, model_name.plural, Searchkick.env, Searchkick.index_suffix].compact.join("_")
        end

      class_eval do
        cattr_reader :searchkick_options, :searchkick_klass

        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_klass, self
        class_variable_set :@@searchkick_index, index_name
        class_variable_set :@@searchkick_index_cache, {}

        class << self
          def searchkick_search(term = "*", **options, &block)
            Searchkick.search(term, {model: self}.merge(options), &block)
          end
          alias_method Searchkick.search_method_name, :searchkick_search if Searchkick.search_method_name

          def searchkick_index
            index = class_variable_get(:@@searchkick_index)
            index = index.call if index.respond_to?(:call)
            index_cache = class_variable_get(:@@searchkick_index_cache)
            index_cache[index] ||= Searchkick::Index.new(index, searchkick_options)
          end
          alias_method :search_index, :searchkick_index unless method_defined?(:search_index)

          def searchkick_reindex(method_name = nil, **options)
            scoped = (respond_to?(:current_scope) && respond_to?(:default_scoped) && current_scope && current_scope.to_sql != default_scoped.to_sql) ||
              (respond_to?(:queryable) && queryable != unscoped.with_default_scope)

            searchkick_index.reindex(searchkick_klass, method_name, scoped: scoped, **options)
          end
          alias_method :reindex, :searchkick_reindex unless method_defined?(:reindex)

          def searchkick_index_options
            searchkick_index.index_options
          end
        end

        # always add callbacks, even when callbacks is false
        # so Model.callbacks block can be used
        if respond_to?(:after_commit)
          after_commit :reindex, if: -> { Searchkick.callbacks?(default: callbacks) }
        elsif respond_to?(:after_save)
          after_save :reindex, if: -> { Searchkick.callbacks?(default: callbacks) }
          after_destroy :reindex, if: -> { Searchkick.callbacks?(default: callbacks) }
        end

        def reindex(method_name = nil, **options)
          RecordIndexer.new(self).reindex(method_name, **options)
        end unless method_defined?(:reindex)

        def similar(options = {})
          self.class.searchkick_index.similar_record(self, options)
        end unless method_defined?(:similar)

        def search_data
          data = respond_to?(:to_hash) ? to_hash : serializable_hash
          data.delete("id")
          data.delete("_id")
          data.delete("_type")
          data
        end unless method_defined?(:search_data)

        def should_index?
          true
        end unless method_defined?(:should_index?)

        if defined?(Cequel) && self < Cequel::Record && !method_defined?(:destroyed?)
          def destroyed?
            transient?
          end
        end
      end
    end
  end
end
