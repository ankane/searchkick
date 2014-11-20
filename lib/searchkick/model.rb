module Searchkick
  module Model

    def searchkick(options = {})
      raise "Only call searchkick once per model" if respond_to?(:searchkick_index)

      class_eval do
        cattr_reader :searchkick_options, :searchkick_klass

        callbacks = options.has_key?(:callbacks) ? options[:callbacks] : true

        class_variable_set :@@searchkick_options, options.dup
        class_variable_set :@@searchkick_klass, self
        class_variable_set :@@searchkick_callbacks, callbacks
        class_variable_set :@@searchkick_index, options[:index_name] || [options[:index_prefix], model_name.plural, Searchkick.env].compact.join("_")

        def self.searchkick_index
          index = class_variable_get :@@searchkick_index
          index = index.call if index.respond_to? :call
          Searchkick::Index.new(index)
        end

        define_singleton_method(Searchkick.search_method_name) do |term = nil, options={}, &block|
          query = Searchkick::Query.new(self, term, options)
          if block
            block.call(query.body)
          end
          if options[:execute] == false
            query
          else
            query.execute
          end
        end
        extend Searchkick::Reindex
        include Searchkick::Similar

        def reindex_async
          if defined?(Searchkick::ReindexV2Job)
            Searchkick::ReindexV2Job.perform_later(self.class.name, id.to_s)
          else
            Delayed::Job.enqueue Searchkick::ReindexJob.new(self.class.name, id.to_s)
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

      end
    end

  end
end
