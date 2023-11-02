require "active_record"
require "disco"
require "opensearch-ruby"
require "searchkick"

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :movies do |t|
    t.string :name
    t.text :embedding
  end
end

class Movie < ActiveRecord::Base
  serialize :embedding, JSON

  searchkick \
    settings: {
      index: {
        knn: true
      }
    },
    mappings: {
      properties: {
        embedding: {
          type: "knn_vector",
          dimension: 20,
          method: {
            name: "hnsw",
            space_type: "cosinesimil",
            engine: "lucene"
          }
        }
      }
    },
    merge_mappings: true

  def search_data
    {
      name: name,
      embedding: embedding
    }
  end
end

data = Disco.load_movielens
recommender = Disco::Recommender.new(factors: 20)
recommender.fit(data)

movies = []
recommender.item_ids.each do |item_id|
  movies << {name: item_id, embedding: recommender.item_factors(item_id).to_a}
end
Movie.insert_all!(movies)

Movie.reindex

movie = Movie.find_by!(name: "Star Wars (1977)")
# uses efficient filtering available in OpenSearch 2.4+
# https://opensearch.org/docs/latest/search-plugins/knn/filter-search-knn/
body = {
  query: {
    knn: {
      embedding: {
        filter:  {bool: {must_not: {term: {_id: movie.id}}}},
        vector: movie.embedding,
        k: 5
      }
    }
  }
}
pp Movie.search(body: body).map(&:name)
