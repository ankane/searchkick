require_relative "test_helper"

class RecordsTest < Minitest::Test
  def test_records
    skip if cequel?

    store_names ["Milk", "Apple"]
    assert_equal Product.search("milk").records.where(name: "Milk").count, 1
  end
end
