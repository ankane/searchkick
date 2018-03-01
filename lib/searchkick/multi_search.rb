module Searchkick
  class MultiSearch
    attr_reader :queries

    def initialize(queries)
      @queries = queries
    end

    def perform
      if queries.any?
        perform_search(queries)
      end
    end

    private

    def perform_search(queries)
      responses = client.msearch(body: queries.flat_map { |q| [q.params.except(:body), q.body] })["responses"]

      retry_queries = []
      queries.each_with_index do |query, i|
        if query.retry_misspellings?(responses[i])
          query.send(:prepare) # okay, since we don't want to expose this method outside Searchkick
          retry_queries << query
        else
          query.handle_response(responses[i])
        end
      end

      if retry_queries.any?
        perform_search(retry_queries)
      end

      queries
    end

    def client
      Searchkick.client
    end
  end
end
