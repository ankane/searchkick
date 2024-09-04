class Product
  searchkick \
    synonyms: [
      ["clorox", "bleach"],
      ["burger", "hamburger"],
      ["bandaid", "bandages"],
      ["UPPERCASE", "lowercase"],
      "lightbulb => led,lightbulb",
      "lightbulb => halogenlamp"
    ],
    suggest: [:name, :color],
    conversions: [:conversions],
    locations: [:location, :multiple_locations],
    text_start: [:name],
    text_middle: [:name],
    text_end: [:name],
    word_start: [:name],
    word_middle: [:name],
    word_end: [:name],
    highlight: [:name],
    filterable: [:name, :color, :description],
    similarity: "BM25",
    match: ENV["MATCH"] ? ENV["MATCH"].to_sym : nil,
    knn: Searchkick.knn_support? ? {
      embedding: {dimensions: 3, distance: "cosine"},
      embedding2: {dimensions: 3, distance: "inner_product"},
      factors: {dimensions: 3, distance: "euclidean"}
    }.merge(Searchkick.opensearch? ? {} : {vector: {dimensions: 3}}) : nil

  attr_accessor :conversions, :user_ids, :aisle, :details

  class << self
    attr_accessor :dynamic_data
  end

  def search_data
    return self.class.dynamic_data.call if self.class.dynamic_data

    serializable_hash.except("id", "_id").merge(
      conversions: conversions,
      user_ids: user_ids,
      location: {lat: latitude, lon: longitude},
      multiple_locations: [{lat: latitude, lon: longitude}, {lat: 0, lon: 0}],
      aisle: aisle,
      details: details
    )
  end

  def should_index?
    name != "DO NOT INDEX"
  end

  def search_name
    {
      name: name
    }
  end
end
