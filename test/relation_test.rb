require_relative "test_helper"

class RelationTest < Minitest::Test
  def test_works
    store_names ["Product A", "Product B"]
    relation = Product.search("product").where(name: "Product A").limit(1).offset(0).order(name: :desc)
    assert_equal ["Product A"], relation.map(&:name)
  end

  def test_no_term
    store_names ["Product A"]
    assert_equal ["Product A"], Product.search.map(&:name)
  end

  def test_where
    store_names ["Product A", "Product B"]
    assert_search_relation [], Product.search("*").where(name: "Product A").where(name: "Product B")
  end

  def test_none
    store_names ["Product A", "Product B"]
    assert_search_relation [], Product.search("*").none
  end

  def test_unscoped
    store_names ["Red", "Blue"]
    # keeps term
    assert_search_relation ["Red"], Product.search("red").where(store_id: 1).unscoped
  end

  def test_unscope
    store_names ["Red", "Blue"]
    assert_search_relation ["Red"], Product.search("red").where(store_id: 1).unscope(:where)
  end

  def test_pluck
    store_names ["Blue", "Red"]
    assert_equal ["Blue", "Red"], Product.order(:name).pluck(:name) if defined?(ActiveRecord)
    assert_equal ["Blue", "Red"], Product.search.order(:name).pluck(:name)
  end

  def test_pluck_many
    store_names ["Blue", "Red"]
    assert_equal [["Blue", nil], ["Red", nil]], Product.order(:name).pluck(:name, :store_id) if defined?(ActiveRecord)
    assert_equal [["Blue", nil], ["Red", nil]], Product.search.order(:name).pluck(:name, :store_id)
  end

  def test_pluck_empty
    Product.search_index.refresh
    assert_equal [], Product.search.pluck
    store_names ["Blue", "Red"]
    assert Product.search.pluck
  end

  def test_parameters
    skip unless defined?(ActiveRecord)
    require "action_controller"

    params = ActionController::Parameters.new({store_id: 1})
    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Product.where(params)
    end
    assert_raises(ActiveModel::ForbiddenAttributesError) do
      Product.search.where(params)
    end
  end
end
