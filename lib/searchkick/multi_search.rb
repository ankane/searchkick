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

    def perform_search(queries, retry_below_misspellings_threshold: true)
      responses = client.msearch(body: queries.flat_map { |q| [q.params.except(:body), q.body] })["responses"]

      queries_below_misspellings_threshold = []
      queries.each_with_index do |query, i|
        if query.below_misspellings_threshold?(responses[i])
          query.prepare
          queries_below_misspellings_threshold << query
        else
          query.handle_response(responses[i])
        end
      end

      if retry_below_misspellings_threshold && queries_below_misspellings_threshold.any?
        perform_search(queries_below_misspellings_threshold, retry_below_misspellings_threshold: false)
      end
    end

    def client
      Searchkick.client
    end
  end
end
