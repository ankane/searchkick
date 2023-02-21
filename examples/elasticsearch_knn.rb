require "active_record"
require "disco"
require "elasticsearch"
require "searchkick"

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :movies do |t|
    t.string :name
    t.binary :embedding
  end
end

class Movie < ActiveRecord::Base
  searchkick \
    mappings: {
      properties: {
        embedding: {
          type: "dense_vector",
          dims: 20,
          index: true,
          similarity: "cosine"
        }
      }
    },
    merge_mappings: true

  def search_data
    {
      name: name,
      embedding: embedding.unpack("f*")
    }
  end
end

data = Disco.load_movielens
recommender = Disco::Recommender.new(factors: 20)
recommender.fit(data)

movies = []
recommender.item_ids.each do |item_id|
  movies << {name: item_id, embedding: recommender.item_factors(item_id).to_binary}
end
Movie.insert_all!(movies)

Movie.reindex

movie = Movie.find_by!(name: "Star Wars (1977)")
body = {
  knn: {
    filter: {bool: {must_not: {term: {_id: movie.id}}}},
    field: "embedding",
    k: 5,
    num_candidates: 5,
    query_vector: movie.embedding.unpack("f*")
  }
}
pp Movie.search(body: body).map(&:name)
