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
    t.text :embedding
  end
end

class Document < ActiveRecord::Base
  # remove "coder: " for Active Record < 7.1
  serialize :embedding, coder: JSON

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
query_embedding = embed.(query, **embed_options)
pp Document.search(knn: {field: :embedding, vector: query_embedding}).map(&:content)
