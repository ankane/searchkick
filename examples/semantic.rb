require "bundler/setup"
require "active_record"
require "elasticsearch" # or "opensearch-ruby"
require "informers"
require "searchkick"

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :documents do |t|
    t.string :content
    t.json :embedding
  end
end

class Document < ActiveRecord::Base
  searchkick knn: {embedding: {dimensions: 768}}
end

embed = Informers.pipeline("embedding", "Snowflake/snowflake-arctic-embed-m-v1.5")
embed_options = {model_output: "sentence_embedding", pooling: "none"} # specific to embedding model

texts = [
  "The dog is barking",
  "The cat is purring",
  "The bear is growling"
]
embeddings = embed.(texts, **embed_options)

documents = []
texts.zip(embeddings) do |content, embedding|
  documents << {content: content, embedding: embedding}
end
Document.insert_all!(documents)

Document.reindex

query = "puppy"

# the query prefix is specific to the embedding model (https://huggingface.co/Snowflake/snowflake-arctic-embed-m-v1.5)
query_prefix = "Represent this sentence for searching relevant passages: "
query_embedding = embed.(query_prefix + query, **embed_options)
pp Document.search(knn: {field: :embedding, vector: query_embedding}).map(&:content)
