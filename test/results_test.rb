require_relative "test_helper"

class ResultsTest < Minitest::Test
  def test_one
    store_names ["Red", "Blue"]
    assert !Product.search("*").one?
    assert Product.search("blue").one?
  end

  def test_many
    store_names ["Red", "Blue"]
    assert Product.search("*").many?
    assert !Product.search("blue").many?
  end
end
