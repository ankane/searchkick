require_relative "test_helper"

class ErrorsTest < Minitest::Test
  def test_bulk_import_raises_error
    valid_dog = Product.create(name: "2016-01-02")
    invalid_dog = Product.create(name: "Ol' One-Leg")
    mapping = {
      properties: {
        name: {type: "date"}
      }
    }
    index = Searchkick::Index.new "dogs", mappings: mapping, _type: "dog"
    index.delete if index.exists?
    index.create_index
    index.store valid_dog
    assert_raises(Searchkick::ImportError) do
      index.bulk_index [valid_dog, invalid_dog]
    end
  end
end
