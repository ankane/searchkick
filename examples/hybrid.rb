require "bundler/setup"
require "active_record"
require "elasticsearch" # or "opensearch-ruby"
require "informers"
require "searchkick"

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :products do |t|
    t.string :name
    t.json :embedding
  end
end

class Product < ActiveRecord::Base
  searchkick knn: {embedding: {dimensions: 768, distance: "cosine"}}
end

Product.reindex

Product.create!(name: "Breakfast cereal")
Product.create!(name: "Ice cream")
Product.create!(name: "Eggs")

embed = Informers.pipeline("embedding", "Snowflake/snowflake-arctic-embed-m-v1.5")
embed_options = {model_output: "sentence_embedding", pooling: "none"} # specific to embedding model

Product.find_each do |product|
  embedding = embed.(product.name, **embed_options)
  product.update!(embedding: embedding)
end

Product.search_index.refresh

query = "breakfast"
keyword_search = Product.search(query, limit: 20)

# the query prefix is specific to the embedding model (https://huggingface.co/Snowflake/snowflake-arctic-embed-m-v1.5)
query_prefix = "Represent this sentence for searching relevant passages: "
query_embedding = embed.(query_prefix + query, **embed_options)
semantic_search = Product.search(knn: {field: :embedding, vector: query_embedding}, limit: 20)

Searchkick.multi_search([keyword_search, semantic_search])

# to combine the results, use Reciprocal Rank Fusion (RRF)
p Searchkick::Reranking.rrf(keyword_search, semantic_search).first(5).map { |v| v[:result].name }

# or a reranking model
rerank = Informers.pipeline("reranking", "mixedbread-ai/mxbai-rerank-xsmall-v1")
results = (keyword_search.to_a + semantic_search.to_a).uniq
p rerank.(query, results.map(&:name)).first(5).map { |v| results[v[:doc_id]] }.map(&:name)
