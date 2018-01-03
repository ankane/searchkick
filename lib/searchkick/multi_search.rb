module Searchkick
  class MultiSearch
    attr_reader :queries

    def initialize(queries, retry_misspellings: false)
      @queries = queries
      @retry_misspellings = retry_misspellings
    end

    def perform
      if queries.any?
        perform_search(queries, retry_misspellings: @retry_misspellings)
      end
    end

    private

    def perform_search(queries, retry_misspellings: true)
      responses = client.msearch(body: queries.flat_map { |q| [q.params.except(:body), q.body] })["responses"]

      retry_queries = []
      queries.each_with_index do |query, i|
        if retry_misspellings && query.retry_misspellings?(responses[i])
          query.send(:prepare) # okay, since we don't want to expose this method outside Searchkick
          retry_queries << query
        else
          query.handle_response(responses[i])
        end
      end

      if retry_misspellings && retry_queries.any?
        perform_search(retry_queries, retry_misspellings: false)
      end

      queries
    end

    def client
      Searchkick.client
    end
  end
end
