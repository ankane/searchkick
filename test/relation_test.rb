require_relative "test_helper"

class RelationTest < Minitest::Test
  def test_loaded
    Product.searchkick_index.refresh
    products = Product.search("*")
    refute products.loaded?
    assert_equal 0, products.count
    assert products.loaded?
    refute products.clone.loaded?
    refute products.dup.loaded?
    refute products.limit(2).loaded?
    error = assert_raises(Searchkick::Error) do
      products.limit!(2)
    end
    assert_equal "Relation loaded", error.message
  end

  def test_mutating
    store_names ["Product A", "Product B"]
    products = Product.search("*").order(:name)
    products.limit!(1)
    assert_equal ["Product A"], products.map(&:name)
  end

  def test_load
    products = Product.search("*")
    refute products.loaded?
    assert products.load.loaded?
    assert products.load.load.loaded?
  end

  def test_clone
    products = Product.search("*")
    assert_equal 10, products.limit(10).limit_value
    assert_equal 10000, products.limit_value
  end

  def test_only
    assert_equal 10, Product.search("*").limit(10).only(:limit).limit_value
  end

  def test_except
    assert_equal 10000, Product.search("*").limit(10).except(:limit).limit_value
  end

  def test_first
    store_names ["Product A", "Product B"]
    products = Product.search("product")
    assert_kind_of Product, products.first
    assert_kind_of Array, products.first(1)
    assert_equal 1, products.limit(1).first(2).size
  end

  def test_first_loaded
    store_names ["Product A", "Product B"]
    products = Product.search("product").load
    assert_kind_of Product, products.first
  end

  # TODO call pluck or select on Active Record query
  # currently uses pluck from Active Support enumerable
  def test_pluck
    store_names ["Product A", "Product B"]
    assert_equal ["Product A", "Product B"], Product.search("product").pluck(:name).sort
    assert_equal ["Product A", "Product B"], Product.search("product").load(false).pluck(:name).sort
  end

  def test_model
    assert_equal Product, Product.search("product").model
    assert_nil Searchkick.search("product").model
  end

  def test_klass
    assert_equal Product, Product.search("product").klass
    assert_nil Searchkick.search("product").klass
  end

  def test_respond_to
    relation = Product.search("product")
    assert relation.respond_to?(:page)
    assert relation.respond_to?(:response)
    assert relation.respond_to?(:size)
    refute relation.respond_to?(:hello)
    refute relation.loaded?
  end

  def test_inspect
    store_names ["Product A"]
    assert_match "#<Searchkick::Relation [#<Product", Product.search("product").inspect
  end

  def test_to_json
    store_names ["Product A", "Product B"]
    if mongoid?
      assert_equal Product.all.to_a.to_json, Product.search("product").to_json
    else
      assert_equal Product.all.to_json, Product.search("product").to_json
    end
  end

  def test_as_json
    store_names ["Product A", "Product B"]
    if mongoid?
      assert_equal Product.all.to_a.as_json, Product.search("product").as_json
    else
      assert_equal Product.all.as_json, Product.search("product").as_json
    end
  end

  def test_to_yaml
    store_names ["Product A", "Product B"]
    if mongoid?
      assert_equal Product.all.to_a.to_yaml, Product.search("product").to_yaml
    else
      assert_equal Product.all.to_yaml, Product.search("product").to_yaml
    end
  end
end
