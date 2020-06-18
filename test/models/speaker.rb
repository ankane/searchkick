class Speaker
  searchkick \
    conversions: ["conversions_a", "conversions_b"],
    search_synonyms: [
      ["clorox", "bleach"],
      ["burger", "hamburger"],
      ["bandaids", "bandages"],
      ["UPPERCASE", "lowercase"],
      "led => led,lightbulb",
      "halogen lamp => lightbulb",
      ["United States of America", "USA"]
    ],
    word_start: [:name]

  attr_accessor :conversions_a, :conversions_b, :aisle

  def search_data
    serializable_hash.except("id", "_id").merge(
      conversions_a: conversions_a,
      conversions_b: conversions_b,
      aisle: aisle
    )
  end
end
