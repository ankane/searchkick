require_relative "test_helper"

class MarshalTest < Minitest::Test
  def test_marshal
    store_names ["Product A"]
    assert Marshal.dump(Product.search("*").results)
  end

  def test_marshal_highlights
    store_names ["Product A"]
    assert Marshal.dump(Product.search("product", highlight: true, load: {dumpable: true}).results)
  end
end
