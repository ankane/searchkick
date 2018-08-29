class Review
  searchkick \
    routing: true,
    merge_mappings: true,
    mappings: {
      properties: {
        name: {type: "keyword"},
        stars: {type: "keyword"}
      }
    }

  def search_document_id
    id
  end

  def search_routing
    name
  end

  def search_data
    serializable_hash.except("id", "_id").merge(
      name: name,
      stars: stars
    )
  end
end
