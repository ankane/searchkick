class Speaker
  searchkick \
    conversions: ["conversions_a", "conversions_b"]

  attr_accessor :conversions_a, :conversions_b, :aisle

  def search_data
    serializable_hash.except("id", "_id").merge(
      conversions_a: conversions_a,
      conversions_b: conversions_b,
      aisle: aisle
    )
  end
end
