module Searchkick
  module Model
    def searchkick(**options)
      options = Searchkick.model_options.merge(options)

      unknown_keywords = options.keys - [:_all, :_type, :batch_size, :callbacks, :case_sensitive, :conversions, :deep_paging, :default_fields,
        :filterable, :geo_shape, :highlight, :ignore_above, :index_name, :index_prefix, :inheritance, :language,
        :locations, :mappings, :match, :max_result_window, :merge_mappings, :routing, :searchable, :search_synonyms, :settings, :similarity,
        :special_characters, :stem, :stemmer, :stem_conversions, :stem_exclusion, :stemmer_override, :suggest, :synonyms, :text_end,
        :text_middle, :text_start, :unscope, :word, :word_end, :word_middle, :word_start, :thread_safe]
      raise ArgumentError, "unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?

      if options[:thread_safe] && !respond_to?(:insert_all)
        raise ArgumentError, 'Use ActiveRecord > 6.0 in order apply thread_safe mode'
      end

      raise "Only call searchkick once per model" if respond_to?(:searchkick_index)

      Searchkick.models << self

      options[:_type] ||= -> { searchkick_index.klass_document_type(self, true) }
      options[:class_name] = model_name.name

      callbacks = options.key?(:callbacks) ? options[:callbacks] : :inline

      base = self

      mod = Module.new
      include(mod)
      mod.module_eval do
        def reindex(method_name = nil, mode: nil, refresh: false)
          arp = after_reindex_params if respond_to?(:after_reindex_params)

          self.class.searchkick_index.reindex([self], method_name: method_name, mode: mode, refresh: refresh, single: true, after_reindex_params: { self.id.to_s => arp })
        end unless base.method_defined?(:reindex)

        def similar(**options)
          self.class.searchkick_index.similar_record(self, **options)
        end unless base.method_defined?(:similar)

        def search_data
          data = respond_to?(:to_hash) ? to_hash : serializable_hash
          data.delete("id")
          data.delete("_id")
          data.delete("_type")
          data
        end unless base.method_defined?(:search_data)

        def should_index?
          true
        end unless base.method_defined?(:should_index?)
      end

      class_eval do
        cattr_reader :searchkick_options, :searchkick_klass, instance_reader: false

        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_klass, self
        class_variable_set :@@searchkick_index_cache, Searchkick::IndexCache.new

        class << self
          def searchkick_search(term = "*", **options, &block)
            if Searchkick.relation?(self)
              raise Searchkick::Error, "search must be called on model, not relation"
            end

            Searchkick.search(term, model: self, **options, &block)
          end
          alias_method Searchkick.search_method_name, :searchkick_search if Searchkick.search_method_name

          def searchkick_index(name: nil)
            index_name = name || searchkick_klass.searchkick_index_name
            index_name = index_name.call if index_name.respond_to?(:call)
            index_cache = class_variable_get(:@@searchkick_index_cache)
            index_cache.fetch(index_name) { Searchkick::Index.new(index_name, searchkick_options) }
          end
          alias_method :search_index, :searchkick_index unless method_defined?(:search_index)

          def searchkick_reindex(method_name = nil, **options)
            searchkick_index.reindex(self, method_name: method_name, **options)
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


        if_callbacks_proc = -> {
          default_callbacks = callbacks.is_a?(Proc) ? instance_exec(&callbacks) : callbacks

          unless [:inline, true, false, :async, :queue].include?(default_callbacks)
            raise ArgumentError, "Invalid value for callbacks"
          end

          Searchkick.callbacks?(default: default_callbacks)
        }
        # always add callbacks, even when callbacks is false
        # so Model.callbacks block can be used
        if respond_to?(:after_commit)
          after_commit :reindex, if: if_callbacks_proc
        elsif respond_to?(:after_save)
          after_save :reindex, if: if_callbacks_proc
          after_destroy :reindex, if: if_callbacks_proc
        end
      end
    end
  end
end
