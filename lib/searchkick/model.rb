module Searchkick
  module Model
    def searchkick(**options)
      unknown_keywords = options.keys - [:batch_size, :callbacks, :conversions,
        :filterable, :geo_shape, :highlight, :ignore_above, :index_name, :index_prefix, :language,
        :locations, :mappings, :match, :merge_mappings, :routing, :searchable, :settings, :similarity,
        :special_characters, :stem_conversions, :suggest, :synonyms, :text_end,
        :text_middle, :text_start, :word, :wordnet, :word_end, :word_middle, :word_start]
      raise ArgumentError, "unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?

      raise "Only call searchkick once per model" if respond_to?(:searchkick_index)

      Searchkick.models << self

      class_eval do
        cattr_reader :searchkick_options, :searchkick_klass

        callbacks = options.key?(:callbacks) ? options[:callbacks] : true

        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_klass, self
        class_variable_set :@@searchkick_callbacks, callbacks
        class_variable_set :@@searchkick_index, options[:index_name] ||
          (options[:index_prefix].respond_to?(:call) && proc { [options[:index_prefix].call, model_name.plural, Searchkick.env].compact.join("_") }) ||
          [options[:index_prefix], model_name.plural, Searchkick.env].compact.join("_")

        class << self
          def searchkick_search(term = "*", **options, &block)
            searchkick_index.search_model(self, term, options, &block)
          end
          alias_method Searchkick.search_method_name, :searchkick_search if Searchkick.search_method_name

          def searchkick_index
            index = class_variable_get :@@searchkick_index
            index = index.call if index.respond_to? :call
            Searchkick::Index.new(index, searchkick_options)
          end

          def enable_search_callbacks
            class_variable_set :@@searchkick_callbacks, true
          end

          def disable_search_callbacks
            class_variable_set :@@searchkick_callbacks, false
          end

          def search_callbacks?
            class_variable_get(:@@searchkick_callbacks) && Searchkick.callbacks?
          end

          def searchkick_reindex(method_name = nil, full: false, **options)
            scoped = (respond_to?(:current_scope) && respond_to?(:default_scoped) && current_scope && current_scope.to_sql != default_scoped.to_sql) ||
              (respond_to?(:queryable) && queryable != unscoped.with_default_scope)

            refresh = options.fetch(:refresh, !scoped)

            if method_name
              # update
              searchkick_index.import_scope(searchkick_klass, method_name: method_name)
              searchkick_index.refresh if refresh
            elsif scoped && !full
              # reindex association
              searchkick_index.import_scope(searchkick_klass)
              searchkick_index.refresh if refresh
            else
              # full reindex
              searchkick_index.reindex_scope(searchkick_klass, options)
            end
            true
          end
          alias_method :reindex, :searchkick_reindex unless method_defined?(:reindex)

          def searchkick_index_options
            searchkick_index.index_options
          end
        end

        callback_name = callbacks == :async ? :reindex_async : :reindex
        if respond_to?(:after_commit)
          after_commit callback_name, if: proc { self.class.search_callbacks? }
        elsif respond_to?(:after_save)
          after_save callback_name, if: proc { self.class.search_callbacks? }
          after_destroy callback_name, if: proc { self.class.search_callbacks? }
        end

        def reindex(method_name = nil, refresh: false)
          if method_name
            self.class.searchkick_index.bulk_update([self], method_name)
          else
            self.class.searchkick_index.reindex_record(self)
          end
          self.class.searchkick_index.refresh if refresh
        end unless method_defined?(:reindex)

        def reindex_async
          self.class.searchkick_index.reindex_record_async(self)
        end unless method_defined?(:reindex_async)

        def similar(options = {})
          self.class.searchkick_index.similar_record(self, options)
        end unless method_defined?(:similar)

        def search_data
          respond_to?(:to_hash) ? to_hash : serializable_hash
        end unless method_defined?(:search_data)

        def should_index?
          true
        end unless method_defined?(:should_index?)
      end
    end
  end
end
