require_relative "test_helper"

class InheritanceTest < Minitest::Test
  def test_child_reindex
    store_names ["Max"], Cat
    assert Dog.reindex
    Animal.searchkick_index.refresh
    assert_equal 1, Animal.search("*").size
  end

  def test_child_index_name
    assert_equal "animals-#{Date.today.year}", Dog.searchkick_index.name
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

  def test_force_one_type
    store_names ["Green Bear"], Dog
    store_names ["Blue Bear"], Cat
    assert_equal ["Blue Bear"], Animal.search("bear", type: [Cat]).map(&:name)
  end

  def test_force_multiple_types
    store_names ["Green Bear"], Dog
    store_names ["Blue Bear"], Cat
    store_names ["Red Bear"], Animal
    assert_equal ["Green Bear", "Blue Bear"], Animal.search("bear", type: [Dog, Cat]).map(&:name)
  end

  def test_child_autocomplete
    store_names ["Max"], Cat
    store_names ["Mark"], Dog
    assert_equal ["Max"], Cat.search("ma", fields: [:name], autocomplete: true).map(&:name)
  end

  def test_parent_autocomplete
    store_names ["Max"], Cat
    store_names ["Bear"], Dog
    assert_equal ["Bear"], Animal.search("bea", fields: [:name], autocomplete: true).map(&:name).sort
  end

  # def test_child_suggest
  #   store_names ["Shark"], Cat
  #   store_names ["Sharp"], Dog
  #   assert_equal ["shark"], Cat.search("shar", fields: [:name], suggest: true).suggestions
  # end

  def test_parent_suggest
    store_names ["Shark"], Cat
    store_names ["Tiger"], Dog
    assert_equal ["tiger"], Animal.search("tige", fields: [:name], suggest: true).suggestions.sort
  end

  def test_reindex
    store_names ["Bear A"], Cat
    store_names ["Bear B"], Dog
    Animal.reindex
    assert_equal 1, Dog.search("bear").size
  end

  # TODO move somewhere better

  def test_multiple_indices
    store_names ["Product A"]
    store_names ["Product B"], Animal
    assert_search "product", ["Product A", "Product B"], index_name: [Product.searchkick_index.name, Animal.searchkick_index.name], conversions: false
  end
end
