module Searchkick
  module Errors
    class Error < StandardError
      attr_reader :elasticsearch_error

      def initialize(message = '', elasticsearch_error = nil)
        @elasticsearch_error = elasticsearch_error

        super(message)
      end
    end

    class MissingIndexError < Error
      def initialize(class_name, elasticsearch_error)
        super("Index missing - run #{class_name}.reindex", elasticsearch_error)
      end
    end

    class InvalidQueryError < Error
      def initialize(elasticsearch_error)
        super("Your query seems invalid here is what Elasticsearch returns: #{elasticsearch_error.message}", elasticsearch_error)
      end
    end

    class DeprecatedVersionError < Error
      MESSAGES = [
        'IllegalArgumentException[minimumSimilarity >= 1]',
        'No query registered for [multi_match]',
        '[match] query does not support [cutoff_frequency]]',
        'No query registered for [function_score]]'
      ].freeze

      def initialize(elasticsearch_error)
        super('This version of Searchkick requires Elasticsearch 0.90.4 or greater', elasticsearch_error)
      end
    end

    class SearchFailedError < Error
      def initialize(elasticsearch_error)
        super("Something went wrong here is what Elasticsearch returns: #{elasticsearch_error.message}", elasticsearch_error)
      end
    end
  end
end
