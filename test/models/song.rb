class Song
  mappings = {
    properties: {
      lyrics: {type: "text"}
    }
  }

  searchkick \
    merge_mappings: true,
    mappings: mappings

  def search_routing
    name
  end
end
