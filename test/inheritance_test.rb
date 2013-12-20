require_relative "test_helper"

class TestInheritance < Minitest::Unit::TestCase

  def setup
    super
    Animal.destroy_all
  end

  def test_child_reindex
    store_names ["Max"], Cat
    assert Dog.reindex
    Animal.searchkick_index.refresh
    assert_equal 1, Animal.search("*").size
  end

  def test_child_index_name
    assert_equal "animals_test", Dog.searchkick_index.name
  end

  def test_child_search
    store_names ["Bear"], Dog
    store_names ["Bear"], Cat
    assert_equal 1, Dog.search("bear").size
  end

  def test_parent_search
    store_names ["Bear"], Dog
    store_names ["Bear"], Cat
    assert_equal 2, Animal.search("bear").size
  end

  def test_child_autocomplete
    store_names ["Max"], Cat
    store_names ["Mark"], Dog
    assert_equal ["Max"], Cat.search("ma", fields: [:name], autocomplete: true).map(&:name)
  end

  def test_parent_autocomplete
    store_names ["Max"], Cat
    store_names ["Mark"], Dog
    assert_equal ["Mark", "Max"], Animal.search("ma", fields: [:name], autocomplete: true).map(&:name).sort
  end

end
