class Store
  mappings = {
    properties: {
      name: {type: "keyword"}
    }
  }
  mappings = {store: mappings} if Searchkick.server_below?("7.0.0")

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
