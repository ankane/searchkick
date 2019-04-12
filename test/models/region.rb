class Region
  searchkick \
    geo_shape: [:territory]

  attr_accessor :territory

  def search_data
    {
      name: name,
      text: text,
      territory: territory
    }
  end
end
