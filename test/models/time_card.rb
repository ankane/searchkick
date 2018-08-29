class TimeCard
  searchkick \
    routing: true,
    merge_mappings: true,
    mappings: {
      properties: {
        hours: {type: 'keyword'}
      }
    }

  def search_document_id
    id
  end

  def search_routing
    hours
  end

  def search_data
    serializable_hash.except("id", "_id").merge(
      hours: hours
    )
  end
end
