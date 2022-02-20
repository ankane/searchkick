module Searchkick
  module Model
    def searchkick(**options)
      options = Searchkick.model_options.merge(options)

      unknown_keywords = options.keys - [:_all, :_type, :batch_size, :callbacks, :case_sensitive, :conversions, :deep_paging, :default_fields,
        :filterable, :geo_shape, :highlight, :ignore_above, :index_name, :index_prefix, :inheritance, :language,
        :locations, :mappings, :match, :merge_mappings, :routing, :searchable, :search_synonyms, :settings, :similarity,
        :special_characters, :stem, :stemmer, :stem_conversions, :stem_exclusion, :stemmer_override, :suggest, :synonyms, :text_end,
        :text_middle, :text_start, :word, :word_end, :word_middle, :word_start]
      raise ArgumentError, "unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?

      raise "Only call searchkick once per model" if respond_to?(:searchkick_index)

      Searchkick.models << self

      options[:_type] ||= -> { searchkick_index.klass_document_type(self, true) }
      options[:class_name] = model_name.name

      callbacks = options.key?(:callbacks) ? options[:callbacks] : :inline
      unless [:inline, true, false, :async, :queue].include?(callbacks)
        raise ArgumentError, "Invalid value for callbacks"
      end

      mod = Module.new
      include(mod)
      mod.module_eval do
        # TODO fix notifications
        def reindex(method_name = nil, mode: nil, refresh: false)
          mode ||= Searchkick.callbacks_value || self.class.searchkick_index.options[:callbacks] || true
          mode = :inline if mode == :bulk
          result = self.class.searchkick_index.send(:record_indexer).reindex([self], mode: mode, method_name: method_name, single: true)
          self.class.searchkick_index.refresh if refresh
          result
        end

        def similar(**options)
          self.class.searchkick_index.similar_record(self, **options)
        end

        def search_data
          data = respond_to?(:to_hash) ? to_hash : serializable_hash
          data.delete("id")
          data.delete("_id")
          data.delete("_type")
          data
        end

        def should_index?
          true
        end
      end

      class_eval do
        cattr_reader :searchkick_options, :searchkick_klass

        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_klass, self
        class_variable_set :@@searchkick_index_cache, {}

        class << self
          def searchkick_search(term = "*", **options, &block)
            if Searchkick.relation?(self)
              raise Searchkick::Error, "search must be called on model, not relation"
            end

            Searchkick.search(term, model: self, **options, &block)
          end
          alias_method Searchkick.search_method_name, :searchkick_search if Searchkick.search_method_name

          def searchkick_index(name: nil)
            index = name || searchkick_index_name
            index = index.call if index.respond_to?(:call)
            index_cache = class_variable_get(:@@searchkick_index_cache)
            index_cache[index] ||= Searchkick::Index.new(index, searchkick_options)
          end
          alias_method :search_index, :searchkick_index unless method_defined?(:search_index)

          def searchkick_reindex(method_name = nil, **options)
            scoped = Searchkick.relation?(self)
            relation = scoped ? all : searchkick_klass.all
            # prevent scope from affecting search_data
            unscoped do
              searchkick_index.reindex(relation, method_name, scoped: scoped, **options)
            end
          end
          alias_method :reindex, :searchkick_reindex unless method_defined?(:reindex)

          def searchkick_index_options
            searchkick_index.index_options
          end

          def searchkick_index_name
            @searchkick_index_name ||= begin
              options = class_variable_get(:@@searchkick_options)
              if options[:index_name]
                options[:index_name]
              elsif options[:index_prefix].respond_to?(:call)
                -> { [options[:index_prefix].call, model_name.plural, Searchkick.env, Searchkick.index_suffix].compact.join("_") }
              else
                [options.key?(:index_prefix) ? options[:index_prefix] : Searchkick.index_prefix, model_name.plural, Searchkick.env, Searchkick.index_suffix].compact.join("_")
              end
            end
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
      end
    end
  end
end
