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
  searchkick knn: {embedding: {dimensions: 768}}
end

Product.reindex

Product.create!(name: "Cereal")
Product.create!(name: "Ice cream")
Product.create!(name: "Eggs")

embed = Informers.pipeline("embedding", "Snowflake/snowflake-arctic-embed-m-v1.5")
embed_options = {model_output: "sentence_embedding", pooling: "none"} # specific to embedding model

# generate embeddings in batches
Product.where(embedding: nil).find_in_batches(batch_size: 16) do |products|
  embeddings = embed.(products.map(&:name), **embed_options)

  Searchkick.callbacks(:bulk) do
    products.zip(embeddings) do |product, embedding|
      product.update!(embedding: embedding)
    end
  end
end

Product.search_index.refresh

query = "breakfast"

# the query prefix is specific to the embedding model (https://huggingface.co/Snowflake/snowflake-arctic-embed-m-v1.5)
query_prefix = "Represent this sentence for searching relevant passages: "
query_embedding = embed.(query_prefix + query, **embed_options)
pp Product.search(knn: {field: :embedding, vector: query_embedding}, limit: 20).map(&:name)
