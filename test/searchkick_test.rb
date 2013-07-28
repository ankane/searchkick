require "test_helper"

class Product < ActiveRecord::Base
  has_many :searches

  searchkick \
    synonyms: [
      ["clorox", "bleach"],
      ["scallion", "greenonion"],
      ["saranwrap", "plasticwrap"],
      ["qtip", "cotton swab"],
      ["burger", "hamburger"],
      ["bandaid", "bandag"]
    ],
    settings: {
      number_of_shards: 1
    },
    conversions: true

  def _source
    as_json.merge conversions: searches.group("query").count
  end
end

class Search < ActiveRecord::Base
  belongs_to :product
end

Product.reindex

class TestSearchkick < Minitest::Unit::TestCase

  def setup
    Search.delete_all
    Product.destroy_all
  end

  # exact

  def test_match
    store_names ["Whole Milk", "Fat Free Milk", "Milk"]
    assert_search "milk", ["Milk", "Whole Milk", "Fat Free Milk"]
  end

  def test_case
    store_names ["Whole Milk", "Fat Free Milk", "Milk"]
    assert_search "MILK", ["Milk", "Whole Milk", "Fat Free Milk"]
  end

  def test_cheese_space_in_index
    store_names ["Pepper Jack Cheese Skewers"]
    assert_search "pepperjack cheese skewers", ["Pepper Jack Cheese Skewers"]
  end

  def test_cheese_space_in_query
    store_names ["Pepperjack Cheese Skewers"]
    assert_search "pepper jack cheese skewers", ["Pepperjack Cheese Skewers"]
  end

  def test_middle_token
    store_names ["Dish Washer Amazing Organic Soap"]
    assert_search "dish soap", ["Dish Washer Amazing Organic Soap"]
  end

  def test_percent
    store_names ["1% Milk", "2% Milk", "Whole Milk"]
    assert_search "1%", ["1% Milk"]
  end

  # ascii

  def test_jalapenos
    store_names ["Jalapeño"]
    assert_search "jalapeno", ["Jalapeño"]
  end

  # stemming

  def test_stemming
    store_names ["Whole Milk", "Fat Free Milk", "Milk"]
    assert_search "milks", ["Milk", "Whole Milk", "Fat Free Milk"]
  end

  # fuzzy

  def test_misspelling_sriracha
    store_names ["Sriracha"]
    assert_search "siracha", ["Sriracha"]
  end

  def test_misspelling_tabasco
    store_names ["Tabasco"]
    assert_search "tobasco", ["Tabasco"]
  end

  def test_misspelling_zucchini
    store_names ["Zucchini"]
    assert_search "zuchini", ["Zucchini"]
  end

  def test_misspelling_ziploc
    store_names ["Ziploc"]
    assert_search "zip lock", ["Ziploc"]
  end

  # conversions

  def test_conversions
    store_conversions [
      {name: "Tomato Sauce", conversions: [{query: "tomato sauce", count: 5}, {query: "tomato", count: 20}]},
      {name: "Tomato Paste", conversions: []},
      {name: "Tomatoes", conversions: [{query: "tomato", count: 10}, {query: "tomato sauce", count: 2}]}
    ]
    assert_search "tomato", ["Tomato Sauce", "Tomatoes", "Tomato Paste"]
  end

  def test_conversions_stemmed
    store_conversions [
      {name: "Tomato A", conversions: [{query: "tomato", count: 2}, {query: "tomatos", count: 2}, {query: "Tomatoes", count: 2}]},
      {name: "Tomato B", conversions: [{query: "tomato", count: 4}]}
    ]
    assert_search "tomato", ["Tomato A", "Tomato B"]
  end

  # spaces

  def test_spaces_in_field
    store_names ["Red Bull"]
    assert_search "redbull", ["Red Bull"]
  end

  def test_spaces_in_query
    store_names ["Dishwasher Soap"]
    assert_search "dish washer", ["Dishwasher Soap"]
  end

  def test_spaces_three_words
    store_names ["Dish Washer Soap", "Dish Washer"]
    assert_search "dish washer soap", ["Dish Washer Soap"]
  end

  def test_spaces_stemming
    store_names ["Almond Milk"]
    assert_search "almondmilks", ["Almond Milk"]
  end

  # keywords

  def test_keywords
    store_names ["Clorox Bleach", "Kroger Bleach", "Saran Wrap", "Kroger Plastic Wrap", "Hamburger Buns", "Band-Aid", "Kroger 12-Pack Bandages"]
    assert_search "clorox", ["Clorox Bleach", "Kroger Bleach"]
    assert_search "saran wrap", ["Saran Wrap", "Kroger Plastic Wrap"]
    assert_search "burger buns", ["Hamburger Buns"]
    assert_search "bandaids", ["Band-Aid", "Kroger 12-Pack Bandages"]
  end

  def test_keywords_qtips
    store_names ["Q Tips", "Kroger Cotton Swabs"]
    assert_search "q tips", ["Q Tips", "Kroger Cotton Swabs"]
  end

  def test_keywords_reverse
    store_names ["Scallions"]
    assert_search "green onions", ["Scallions"]
  end

  def test_keywords_exact
    store_names ["Green Onions", "Yellow Onions"]
    assert_search "scallion", ["Green Onions"]
  end

  def test_keywords_stemmed
    store_names ["Green Onions", "Yellow Onions"]
    assert_search "scallions", ["Green Onions"]
  end

  # global boost

  def test_boost
    store [
      {name: "Organic Tomato A"},
      {name: "Tomato B", orders_count: 10}
    ]
    assert_search "tomato", ["Tomato B", "Organic Tomato A"], boost: "orders_count"
  end

  def test_boost_zero
    store [
      {name: "Zero Boost", orders_count: 0}
    ]
    assert_search "zero", ["Zero Boost"], boost: "orders_count"
  end

  # search method

  def test_limit
    store_names ["Product A", "Product B"]
    assert_equal 1, Product.search("Product", limit: 1).size
  end

  def test_offset
    store_names ["Product A", "Product B"]
    assert_equal 1, Product.search("Product", offset: 1).size
  end

  def test_where
    now = Time.now
    store [
      {name: "Product A", store_id: 1, in_stock: true, backordered: true, created_at: now, orders_count: 4},
      {name: "Product B", store_id: 2, in_stock: true, backordered: false, created_at: now - 1, orders_count: 3},
      {name: "Product C", store_id: 3, in_stock: false, backordered: true, created_at: now - 2, orders_count: 2},
      {name: "Product D", store_id: 4, in_stock: false, backordered: false, created_at: now - 3, orders_count: 1},
    ]
    assert_search "product", ["Product A", "Product B"], where: {in_stock: true}
    # date
    assert_search "product", ["Product A"], where: {created_at: {gt: now - 1}}
    assert_search "product", ["Product A", "Product B"], where: {created_at: {gte: now - 1}}
    assert_search "product", ["Product D"], where: {created_at: {lt: now - 2}}
    assert_search "product", ["Product C", "Product D"], where: {created_at: {lte: now - 2}}
    # integer
    assert_search "product", ["Product A"], where: {store_id: {lt: 2}}
    assert_search "product", ["Product A", "Product B"], where: {store_id: {lte: 2}}
    assert_search "product", ["Product D"], where: {store_id: {gt: 3}}
    assert_search "product", ["Product C", "Product D"], where: {store_id: {gte: 3}}
    # range
    assert_search "product", ["Product A", "Product B"], where: {store_id: 1..2}
    assert_search "product", ["Product A"], where: {store_id: 1...2}
    assert_search "product", ["Product A", "Product B"], where: {store_id: [1, 2]}
    assert_search "product", ["Product B", "Product C", "Product D"], where: {store_id: {not: 1}}
    assert_search "product", ["Product C", "Product D"], where: {store_id: {not: [1, 2]}}
    assert_search "product", ["Product A", "Product B", "Product C"], where: {or: [[{in_stock: true}, {store_id: 3}]]}
  end

  def test_order
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_search "product", ["Product D", "Product C", "Product B", "Product A"], order: {name: :desc}
  end

  def test_facets
    store [
      {name: "Product Show", store_id: 1, in_stock: true, color: "blue"},
      {name: "Product Hide", store_id: 2, in_stock: false, color: "green"},
      {name: "Product B", store_id: 2, in_stock: false, color: "red"}
    ]
    assert_equal 2, Product.search("Product", facets: [:store_id]).facets["store_id"]["terms"].size
    assert_equal 1, Product.search("Product", facets: {store_id: {where: {in_stock: true}}}).facets["store_id"]["terms"].size
    assert_equal 1, Product.search("Product", facets: {store_id: {where: {in_stock: true, color: "blue"}}}).facets["store_id"]["terms"].size
  end

  def test_partial
    store_names ["Honey"]
    assert_search "fresh honey", []
    assert_search "fresh honey", ["Honey"], partial: true
  end

  protected

  def store(documents)
    documents.each do |document|
      Product.create!(document)
    end
    Product.index.refresh
  end

  def store_names(names)
    store names.map{|name| {name: name} }
  end

  def store_conversions(documents)
    documents.each do |document|
      conversions = document.delete(:conversions)
      product = Product.create!(document)
      conversions.each do |c|
        c[:count].times do
          product.searches.create!(query: c[:query])
        end
      end
    end
    Product.reindex
    Product.index.refresh
  end

  def assert_search(term, expected, options = {})
    assert_equal expected, Product.search(term, options.merge(fields: [:name], conversions: true)).map(&:name)
  end

end
