require_relative "test_helper"

class ErrorsTest < Minitest::Test
  def test_bulk_import_raises_with_full_message
    valid_dog = Dog.new(name: "2016-01-02")
    invalid_dog = Dog.new(name: "Ol' One-Leg")
    index = Searchkick::Index.new "dogs", mappings: {
      dog: {
        properties: {
          name: {type: "date"}
        }
      }
    }
    index.store valid_dog
    error = assert_raises(Searchkick::ImportError) do
      index.bulk_index [valid_dog, invalid_dog]
    end
  end
end
