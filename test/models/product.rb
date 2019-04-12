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
    match: ENV["MATCH"] ? ENV["MATCH"].to_sym : nil

  attr_accessor :conversions, :user_ids, :aisle, :details

  def search_data
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
