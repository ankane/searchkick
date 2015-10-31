module Searchkick
  module Reindex; end # legacy for Searchjoy

  module Model
    def searchkick(options = {})
      raise "Only call searchkick once per model" if respond_to?(:searchkick_index)

      Searchkick.models << self

      class_eval do
        cattr_reader :searchkick_options, :searchkick_klass

        callbacks = options.key?(:callbacks) ? options[:callbacks] : true

        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_klass, self
        class_variable_set :@@searchkick_callbacks, callbacks
        class_variable_set :@@searchkick_index, options[:index_name] || [options[:index_prefix], model_name.plural, Searchkick.env].compact.join("_")

        class << self
          def searchkick_search(term = nil, options = {}, &block)
            searchkick_index.search_model(self, term, options, &block)
          end
          alias_method Searchkick.search_method_name, :searchkick_search

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

          def searchkick_reindex(options = {})
            unless options[:accept_danger]
              if (respond_to?(:current_scope) && respond_to?(:default_scoped) && current_scope && current_scope.to_sql != default_scoped.to_sql) ||
                (respond_to?(:queryable) && queryable != unscoped.with_default_scope)
                raise Searchkick::DangerousOperation, "Only call reindex on models, not relations. Pass `accept_danger: true` if this is your intention."
              end
            end
            searchkick_index.reindex_scope(searchkick_klass, options)
          end
          alias_method :reindex, :searchkick_reindex unless method_defined?(:reindex)

          def clean_indices
            searchkick_index.clean_indices
          end

          def searchkick_import(options = {})
            (options[:index] || searchkick_index).import_scope(searchkick_klass)
          end

          def searchkick_create_index
            searchkick_index.create_index
          end

          def searchkick_index_options
            searchkick_index.index_options
          end
        end
        extend Searchkick::Reindex # legacy for Searchjoy

        if callbacks
          callback_name = callbacks == :async ? :reindex_async : :reindex
          if respond_to?(:after_commit)
            after_commit callback_name, if: proc { self.class.search_callbacks? }
          else
            after_save callback_name, if: proc { self.class.search_callbacks? }
            after_destroy callback_name, if: proc { self.class.search_callbacks? }
          end
        end

        def reindex
          self.class.searchkick_index.reindex_record(self)
        end unless method_defined?(:reindex)

        def reindex_async
          self.class.searchkick_index.reindex_record_async(self)
        end unless method_defined?(:reindex_async)

        def reindex_update(updates)
          self.class.searchkick_index.update_record(self, updates)
        end unless method_defined?(:reindex_update)

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
