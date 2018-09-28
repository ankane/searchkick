class Store
  searchkick \
    routing: true,
    merge_mappings: true,
    mappings: {
      store: {
        properties: {
          name: {type: "keyword"}
        }
      }
    }

  def search_document_id
    id
  end

  def search_routing
    name
  end
end
