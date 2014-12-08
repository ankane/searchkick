module Searchkick
  module Reindex; end # legacy for Searchjoy

  module Model

    def searchkick(options = {})
      raise "Only call searchkick once per model" if respond_to?(:searchkick_index)

      Searchkick.models << self

      class_eval do
        cattr_reader :searchkick_options, :searchkick_klass

        callbacks = options.has_key?(:callbacks) ? options[:callbacks] : true

        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_klass, self
        class_variable_set :@@searchkick_callbacks, callbacks
        class_variable_set :@@searchkick_index, options[:index_name] || [options[:index_prefix], model_name.plural, Searchkick.env].compact.join("_")

        define_singleton_method(Searchkick.search_method_name) do |term = nil, options={}, &block|
          searchkick_index.search_model(self, term, options, &block)
        end
        extend Searchkick::Reindex # legacy for Searchjoy

        class << self

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

          def reindex(options = {})
            searchkick_index.reindex_scope(searchkick_klass, options)
          end

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

        if callbacks
          callback_name = callbacks == :async ? :reindex_async : :reindex
          if respond_to?(:after_commit)
            after_commit callback_name, if: proc{ self.class.search_callbacks? }
          else
            after_save callback_name, if: proc{ self.class.search_callbacks? }
            after_destroy callback_name, if: proc{ self.class.search_callbacks? }
          end
        end

        def reindex
          self.class.searchkick_index.reindex_record(self)
        end

        def reindex_async
          self.class.searchkick_index.reindex_record_async(self)
        end

        def similar(options = {})
          self.class.searchkick_index.similar_record(self, options)
        end

        def search_data
          respond_to?(:to_hash) ? to_hash : serializable_hash
        end

        def should_index?
          true
        end

      end
    end

  end
end
