class Store
  mappings = {
    properties: {
      name: {type: "text"}
    }
  }

  searchkick \
    routing: true,
    merge_mappings: true,
    mappings: mappings

  def search_document_id
    id
  end

  def search_routing
    name
  end
end
