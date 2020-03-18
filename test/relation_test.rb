require_relative "test_helper"

class RelationTest < Minitest::Test
  def test_works
    store_names ["Product A", "Product B"]
    p Product.search("product", relation: true).where(name: "Product A").limit(1)
  end

  def test_no_term
    store_names ["Product A"]
    p Product.search(relation: true)
  end
end
