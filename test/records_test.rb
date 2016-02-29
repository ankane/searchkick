require_relative "test_helper"

class RecordsTest < Minitest::Test
  def test_records_preserves_order
    store_names ["Milk 1", "Milk 2", "Apple"]
    # search("milk 2") will match "Milk 2" first, and "Milk 1" second
    assert_equal Product.search("milk 2").records.where('name LIKE "%Milk%"').map(&:name), ['Milk 2', 'Milk 1']
  end
end
