require_relative "test_helper"

class LoadTest < Minitest::Test
  def test_default
    store_names ["Product A"]
    product = Product.search("product").first
    assert_kind_of Product, product
    if mongoid?
      assert_match "#<Product _id: ", product.inspect
    else
      assert_match "#<Product id: ", product.inspect
    end
    assert_equal "Product A", product.name
    assert_equal "Product A", product[:name]
    assert_equal "Product A", product["name"]
    refute product.respond_to?(:missing)
    assert_nil product[:missing]
    assert_equal "Product A", product.attributes["name"]
    assert_equal "Product A", product.as_json["name"]
    assert_equal "Product A", JSON.parse(product.to_json)["name"]
    assert_equal "Product A", JSON.parse(Product.search("product").to_json).first["name"]
    assert_equal "Product A", Product.search("product").as_json.first["name"]
    assert_equal ({"name" => "Product A"}), product.as_json(only: ["name"])
    assert_equal ({"name" => "Product A"}), product.as_json(only: [:name])
    refute product.as_json(except: ["name"]).key?("name")
    refute product.as_json(except: [:name]).key?("name")
    assert_empty product.as_json(only: ["missing"])
    if mongoid?
      product.as_json(methods: [:missing])
    else
      assert_raises(NoMethodError) do
        product.as_json(methods: [:missing])
      end
    end
  end

  def test_false
    store_names ["Product A"]
    product = Product.search("product", load: false).first
    assert_kind_of Searchkick::HashWrapper, product
    assert_match "#<Searchkick::HashWrapper id: ", product.inspect
    assert_equal "Product A", product.name
    assert_equal "Product A", product[:name]
    assert_equal "Product A", product["name"]
    refute product.respond_to?(:missing)
    assert_nil product[:missing]
    assert_equal "Product A", product.to_h["name"]
    assert_equal "Product A", product.as_json["name"]
    assert_equal "Product A", JSON.parse(product.to_json)["name"]
    assert_equal "Product A", JSON.parse(Product.search("product", load: false).to_json).first["name"]
    assert_equal "Product A", Product.search("product", load: false).as_json.first["name"]
    assert_equal ({"name" => "Product A"}), product.as_json(only: ["name"])
    # same behavior as Hashie::Mash
    assert_empty product.as_json(only: [:name])
    refute product.as_json(except: ["name"]).key?("name")
    # same behavior as Hashie::Mash
    assert product.as_json(except: [:name]).key?("name")
    assert_empty product.as_json(only: ["missing"])
    # same behavior as Hashie::Mash
    product.as_json(methods: [:missing])
  end

  def test_false_methods
    store_names ["Product A"]
    assert_equal "Product A", Product.search("product", load: false).first.name
  end

  def test_false_with_includes
    store_names ["Product A"]
    assert_kind_of Searchkick::HashWrapper, Product.search("product", load: false, includes: [:store]).first
  end

  def test_false_nested_object
    aisle = {"id" => 1, "name" => "Frozen"}
    store [{name: "Product A", aisle: aisle}]
    assert_equal aisle, Product.search("product", load: false).first.aisle.to_hash
  end
end
