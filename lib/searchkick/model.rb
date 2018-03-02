module Searchkick
  module Model
    def searchkick(**options)
      unknown_keywords = options.keys - [:_all, :_type, :batch_size, :callbacks, :conversions, :default_fields,
        :filterable, :geo_shape, :highlight, :ignore_above, :index_name, :index_prefix, :inheritance, :language,
        :locations, :mappings, :match, :merge_mappings, :routing, :searchable, :settings, :similarity,
        :special_characters, :stem_conversions, :suggest, :synonyms, :text_end,
        :text_middle, :text_start, :word, :wordnet, :word_end, :word_middle, :word_start]
      raise ArgumentError, "unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?

      raise "Only call searchkick once per model" if respond_to?(:searchkick_index)

      Searchkick.models << self

      options[:_type] ||= -> { searchkick_index.klass_document_type(self, true) }

      class_eval do
        cattr_reader :searchkick_options, :searchkick_klass

        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_klass, self
        class_variable_set :@@searchkick_index, options[:index_name] ||
          (options[:index_prefix].respond_to?(:call) && proc { [options[:index_prefix].call, model_name.plural, Searchkick.env, Searchkick.index_suffix].compact.join("_") }) ||
          [options.key?(:index_prefix) ? options[:index_prefix] : Searchkick.index_prefix, model_name.plural, Searchkick.env, Searchkick.index_suffix].compact.join("_")

        class << self
          def searchkick_search(term = "*", **options, &block)
            Searchkick.search(term, {model: self}.merge(options), &block)
          end
          alias_method Searchkick.search_method_name, :searchkick_search if Searchkick.search_method_name

          def searchkick_index
            index = class_variable_get :@@searchkick_index
            index = index.call if index.respond_to? :call
            Searchkick::Index.new(index, searchkick_options)
          end
          alias_method :search_index, :searchkick_index unless method_defined?(:search_index)

          def searchkick_reindex(method_name = nil, full: false, **options)
            return unless Searchkick.callbacks?

            scoped = (respond_to?(:current_scope) && respond_to?(:default_scoped) && current_scope && current_scope.to_sql != default_scoped.to_sql) ||
              (respond_to?(:queryable) && queryable != unscoped.with_default_scope)

            refresh = options.fetch(:refresh, !scoped)

            if method_name
              # update
              searchkick_index.import_scope(searchkick_klass, method_name: method_name)
              searchkick_index.refresh if refresh
              true
            elsif scoped && !full
              # reindex association
              searchkick_index.import_scope(searchkick_klass)
              searchkick_index.refresh if refresh
              true
            else
              # full reindex
              searchkick_index.reindex_scope(searchkick_klass, options)
            end
          end
          alias_method :reindex, :searchkick_reindex unless method_defined?(:reindex)

          def searchkick_index_options
            searchkick_index.index_options
          end
        end

        callbacks = options.key?(:callbacks) ? options[:callbacks] : true
        raise ArgumentError, "Unknown value for callbacks" unless [true, false, :async, :queue].include?(callbacks)

        if callbacks
          if respond_to?(:after_commit)
            after_commit :reindex
          elsif respond_to?(:after_save)
            after_save :reindex
            after_destroy :reindex
          end
        end

        def reindex(method_name = nil, refresh: false, mode: nil)
          return unless Searchkick.callbacks?

          klass_options = self.class.searchkick_index.options

          if mode.nil?
            mode =
              if Searchkick.callbacks_value
                Searchkick.callbacks_value
              else
                klass_options[:callbacks]
              end
          end

          case mode
          when :queue
            if method_name
              raise Searchkick::Error, "Partial reindex not supported with queue option"
            else
              self.class.searchkick_index.reindex_queue.push(id.to_s)
            end
          when :async
            if method_name
              # TODO support Mongoid and NoBrainer and non-id primary keys
              Searchkick::BulkReindexJob.perform_later(
                class_name: self.class.name,
                record_ids: [id.to_s],
                method_name: method_name ? method_name.to_s : nil
              )
            else
              self.class.searchkick_index.reindex_record_async(self)
            end
          else
            if method_name
              self.class.searchkick_index.update_record(self, method_name)
            else
              self.class.searchkick_index.reindex_record(self)
            end
            self.class.searchkick_index.refresh if refresh
          end
        end unless method_defined?(:reindex)

        def similar(options = {})
          self.class.searchkick_index.similar_record(self, options)
        end unless method_defined?(:similar)

        def search_data
          (respond_to?(:to_hash) ? to_hash : serializable_hash).except("id", "_id")
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
