require_relative "test_helper"

class ErrorsTest < Minitest::Test
  def test_bulk_import_raises_with_full_message
    valid_dog = Dog.new(id: 1, name: "2016-01-02")
    invalid_dog = Dog.new(id: 2, name: "Ol' One-Leg")
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
    assert_match /on item with id '2'/, error.message
  end
end
