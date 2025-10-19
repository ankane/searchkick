require_relative "test_helper"

class MarshalTest < Minitest::Test
  def test_marshal
    store_names ["Product A"]
    assert Marshal.dump(Product.search("*").to_a)
  end

  def test_marshal_highlights
    store_names ["Product A"]
    assert Marshal.dump(Product.search("product", highlight: true, load: {dumpable: true}).to_a)
  end
end
