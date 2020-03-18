require_relative "test_helper"

class ResultsTest < Minitest::Test
  def test_none
    store_names ["Red", "Blue"]
    assert Product.search("green").none?
    assert !Product.search("blue").none?
    assert !Product.search("*").none?
  end

  def test_one
    store_names ["Red", "Blue"]
    assert !Product.search("green").one?
    assert Product.search("blue").one?
    assert !Product.search("*").one?
  end

  def test_many
    store_names ["Red", "Blue"]
    assert !Product.search("green").many?
    assert !Product.search("blue").many?
    assert Product.search("*").many?
  end
end
