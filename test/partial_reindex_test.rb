require_relative "test_helper"

class PartialReindexTest < Minitest::Test
  def test_class_method
    store [{name: "Hi", color: "Blue"}]

    # normal search
    assert_search "hi", ["Hi"], fields: [:name], load: false
    assert_search "blue", ["Hi"], fields: [:color], load: false

    # update
    product = Product.first
    product.name = "Bye"
    product.color = "Red"
    Searchkick.callbacks(false) do
      product.save!
    end
    Product.searchkick_index.refresh

    # index not updated
    assert_search "hi", ["Hi"], fields: [:name], load: false
    assert_search "blue", ["Hi"], fields: [:color], load: false

    # partial reindex
    Product.reindex(:search_name)

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false
  end

  def test_instance_method
    store [{name: "Hi", color: "Blue"}]

    # normal search
    assert_search "hi", ["Hi"], fields: [:name], load: false
    assert_search "blue", ["Hi"], fields: [:color], load: false

    # update
    product = Product.first
    product.name = "Bye"
    product.color = "Red"
    Searchkick.callbacks(false) do
      product.save!
    end
    Product.searchkick_index.refresh

    # index not updated
    assert_search "hi", ["Hi"], fields: [:name], load: false
    assert_search "blue", ["Hi"], fields: [:color], load: false

    product.reindex(:search_name, refresh: true)

    # name updated, but not color
    assert_search "bye", ["Bye"], fields: [:name], load: false
    assert_search "blue", ["Bye"], fields: [:color], load: false
  end
end
