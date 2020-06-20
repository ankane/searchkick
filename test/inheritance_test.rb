require_relative "test_helper"

class InheritanceTest < Minitest::Test
  def setup
    skip if cequel?
    super
  end

  def test_child_reindex
    store_names ["Max"], Cat
    assert Dog.reindex
    assert_equal 1, Animal.search("*").size
  end

  def test_child_index_name
    assert_equal "animals-#{Date.today.year}#{ENV["TEST_ENV_NUMBER"]}", Dog.searchkick_index.name
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
    assert_equal ["Max"], Cat.search("ma", fields: [:name], match: :text_start).map(&:name)
  end

  def test_parent_autocomplete
    store_names ["Max"], Cat
    store_names ["Bear"], Dog
    assert_equal ["Bear"], Animal.search("bea", fields: [:name], match: :text_start).map(&:name).sort
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
    assert_equal 2, Animal.search("bear").size
  end

  def test_child_models_option
    store_names ["Bear A"], Cat
    store_names ["Bear B"], Dog
    Animal.reindex
    # note: the models option is less efficient than Animal.search("bear", type: [Cat, Dog])
    # since it requires two database calls instead of one to Animal
    assert_equal 2, Searchkick.search("bear", models: [Cat, Dog]).size
  end

  def test_inherited_and_non_inherited_models
    store_names ["Bear A"], Cat
    store_names ["Bear B"], Dog
    store_names ["Bear C"]
    Animal.reindex
    assert_equal 2, Searchkick.search("bear", models: [Cat, Product]).size

    # hits and pagination will be off with this approach (for now)
    # ideal case is add where conditions (index a, type a OR index b)
    # however, we don't know the exact index name and aliases don't work for filters
    # see https://github.com/elastic/elasticsearch/issues/23306
    # show warning for now
    # alternative is disallow inherited models with models option
    expected = Searchkick.server_below?("7.5.0") ? 3 : 2
    assert_equal expected, Searchkick.search("bear", models: [Cat, Product]).hits.size
    assert_equal expected, Searchkick.search("bear", models: [Cat, Product], per_page: 1).total_pages
  end

  # TODO move somewhere better

  def test_multiple_indices
    store_names ["Product A"]
    store_names ["Product B"], Animal
    assert_search "product", ["Product A", "Product B"], {models: [Product, Animal], conversions: false}, Searchkick
    assert_search "product", ["Product A", "Product B"], {index_name: [Product, Animal], conversions: false}, Searchkick
  end

  def test_index_name_model
    store_names ["Product A"]
    assert_equal ["Product A"], Searchkick.search("product", index_name: [Product]).map(&:name)
  end

  def test_index_name_string
    store_names ["Product A"]
    error = assert_raises Searchkick::Error do
      Searchkick.search("product", index_name: [Product.searchkick_index.name]).map(&:name)
    end
    assert_includes error.message, "Unknown model"
  end
end
