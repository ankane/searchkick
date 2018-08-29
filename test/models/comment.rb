class Comment
  searchkick \
    routing: true,
    merge_mappings: true,
    mappings: {
      properties: {
        status: {type: "keyword"},
        message: {type: "keyword"}
      }
    }

  def search_document_id
    id
  end

  def search_routing
    status
  end

  def search_data
    serializable_hash.except("id", "_id").merge(
      status: status,
      message: message
    )
  end
end
