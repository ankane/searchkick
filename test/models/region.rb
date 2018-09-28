class Region
  searchkick \
    geo_shape: {
      territory: {tree: "quadtree", precision: "10km"}
    }

  attr_accessor :territory

  def search_data
    {
      name: name,
      text: text,
      territory: territory
    }
  end
end
