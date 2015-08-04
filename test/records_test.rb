require_relative "test_helper"

class RecordsTest < Minitest::Test

  def test_records
    return if defined?(Mongoid) || defined?(NoBrainer)
    store_names ["Milk", "Apple"]
    query = Product.search("milk")
    records = query.records
    refute_equal Array, records.class
  end

end
