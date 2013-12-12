require_relative "test_helper"

class TestInheritance < Minitest::Test

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

end
