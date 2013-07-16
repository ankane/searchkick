require "test_helper"

class Product < ActiveRecord::Base
  searchkick \
    synonyms: [
      "clorox => bleach",
      "saranwrap => plastic wrap",
      "scallion => green onion",
      "qtip => cotton swab",
      "burger => hamburger",
      "bandaid => bandag"
    ],
    settings: {
      number_of_shards: 1
    },
    conversions: true

  # searchkick do
  #   string :name
  #   boolean :visible
  #   integer :orders_count
  # end
end

p Product.index_types

class TestSearchkick < Minitest::Unit::TestCase

  def setup
    Product.index.delete
    Product.create_elasticsearch_index
  end

  def test_reindex
    assert Product.reindex
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
    store [
      {name: "Tomato Sauce", conversions: [{query: "tomato sauce", count: 5}, {query: "tomato", count: 200}]},
      {name: "Tomato Paste", conversions: []},
      {name: "Tomatoes", conversions: [{query: "tomato", count: 100}, {query: "tomato sauce", count: 2}]}
    ]
    assert_search "tomato", ["Tomato Sauce", "Tomatoes", "Tomato Paste"]
  end

  def test_conversions_stemmed
    store [
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
      {name: "Organic Tomato A", _boost: 10},
      {name: "Tomato B"}
    ]
    assert_search "tomato", ["Organic Tomato A", "Tomato B"]
  end

  def test_boost_zero
    store [
      {name: "Zero Boost", _boost: 0}
    ]
    assert_search "zero", ["Zero Boost"]
  end

  # default to 1
  def test_boost_null
    store [
      {name: "Zero Boost A", _boost: 1.1},
      {name: "Zero Boost B"},
      {name: "Zero Boost C", _boost: 0.9},
    ]
    assert_search "zero", ["Zero Boost A", "Zero Boost B", "Zero Boost C"]
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
    store [
      {name: "Product Show", visible: true},
      {name: "Product Hide", visible: false}
    ]
    assert_equal "Product Show", Product.search("Product", where: {visible: true}).first.name
    assert_equal "Product Hide", Product.search("Product", where: {visible: false}).first.name
  end

  protected

  def store(documents)
    documents.each do |document|
      Product.index.store ({_type: "product", visible: true}).merge(document)
    end
    Product.index.refresh
  end

  def store_names(names)
    store names.map{|name| {name: name} }
  end

  def assert_search(term, expected)
    assert_equal expected, Product.search(term, conversions: true).map(&:name)
  end

end
