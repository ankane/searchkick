require_relative "test_helper"

class ErrorsTest < Minitest::Test
  def test_bulk_import_raises_with_full_message
    valid_dog = Dog.new(name: "2016-01-01")
    invalid_dog_1 = Dog.new(name: "Bucket")
    invalid_dog_2 = Dog.new(name: "Ol' One-Leg")
    index = Searchkick::Index.new "dogs"
    message = nil
    begin
      index.bulk_index [valid_dog, invalid_dog_1, invalid_dog_2]
    rescue Searchkick::ImportError => e
      message = e.message
    end
    assert_match /MapperParsingException.*Bucket.*Ol' One-Leg/m, message
  end
end
