module Searchkick
  module Model
    def searchkick(**options)
      options = Searchkick.model_options.merge(options)

      unknown_keywords = options.keys - [:_all, :_type, :batch_size, :callbacks, :case_sensitive, :conversions, :deep_paging, :default_fields,
        :filterable, :geo_shape, :highlight, :ignore_above, :index_name, :index_prefix, :inheritance, :language,
        :locations, :mappings, :match, :merge_mappings, :routing, :searchable, :search_synonyms, :settings, :similarity,
        :special_characters, :stem, :stemmer, :stem_conversions, :stem_exclusion, :stemmer_override, :suggest, :synonyms, :text_end,
        :text_middle, :text_start, :word, :wordnet, :word_end, :word_middle, :word_start]
      raise ArgumentError, "unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?

      raise "Only call searchkick once per model" if respond_to?(:searchkick_index)

      Searchkick.models << self

      options[:_type] ||= -> { searchkick_index.klass_document_type(self, true) }
      options[:class_name] = model_name.name

      callbacks = options.key?(:callbacks) ? options[:callbacks] : :inline
      unless [:inline, true, false, :async, :queue].include?(callbacks)
        raise ArgumentError, "Invalid value for callbacks"
      end

      class_eval do
        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_index_cache, {}

        delegate :searchkick_klass, :searchkick_options, to: self

        class << self
          def searchkick_klass
            searchkick_target
          end

          def searchkick_target
            @searchkick_target ||=
              if superclass.respond_to?(:searchkick_index) &&
                class_variable_get(:@@searchkick_options)&.fetch(:inheritance, false)

                superclass
              else
                self
              end
          end

          def searchkick_options
            @searchkick_options ||= class_variable_get(:@@searchkick_options).to_h.merge(
              class_name: searchkick_target.name
            )
          end

          def searchkick_index_name
            @searchkick_index_name ||=
              if searchkick_options[:index_name]
                searchkick_options[:index_name]
              elsif searchkick_options[:index_prefix].respond_to?(:call)
                -> { build_searchkick_index_name(searchkick_options[:index_prefix].call) }
              else
                build_searchkick_index_name(searchkick_options[:index_prefix])
              end
          end

          def build_searchkick_index_name(prefix = nil)
            parts = [
              prefix || Searchkick.index_prefix,
              defined?(table_name) ? table_name : model_name.plural,
              Searchkick.env,
              Searchkick.index_suffix
            ]

            parts.compact.join("_")
          end

          def searchkick_search(term = "*", **options, &block)
            # TODO throw error in next major version
            Searchkick.warn("calling search on a relation is deprecated") if Searchkick.relation?(self)

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
            # TODO relation = Searchkick.relation?(self)
            relation = (respond_to?(:current_scope) && respond_to?(:default_scoped) && current_scope && current_scope.to_sql != default_scoped.to_sql) ||
              (respond_to?(:queryable) && queryable != unscoped.with_default_scope)

            searchkick_index.reindex(searchkick_klass, method_name, scoped: relation, **options)
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

        # TODO switch to keyword arguments
        def similar(options = {})
          self.class.searchkick_index.similar_record(self, **options)
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
