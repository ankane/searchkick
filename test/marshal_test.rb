require_relative "test_helper"

class MarshalTest < Minitest::Test
  def test_marshal
    store_names ["Product A"]
    assert Marshal.dump(Product.search("*", load: {dumpable: true}).results)
  end
end
