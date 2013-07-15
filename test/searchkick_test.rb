require "test_helper"

class TestSearchkick < Minitest::Unit::TestCase

  def setup
    $index = Tire::Index.new("products")
    $index.delete
    index_options = {
      settings: Searchkick.settings.merge(number_of_shards: 1),
      mappings: {
        document: {
          properties: {
            name: {
              type: "string",
              analyzer: "searchkick"
            },
            conversions: {
              type: "nested",
              properties: {
                query: {
                  type: "string",
                  analyzer: "searchkick_keyword"
                },
                count: {
                  type: "integer"
                }
              }
            }
          }
        }
      }
    }
    $index.create index_options
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
      {name: "Tomato Sauce", conversions: [{query: "tomato sauce", count: 100}, {query: "tomato", count: 2}]},
      {name: "Tomato Paste", conversions: []},
      {name: "Tomatoes", conversions: [{query: "tomato", count: 100}, {query: "tomato sauce", count: 2}]}
    ]
    assert_search "tomato sauce", ["Tomato Sauce", "Tomatoes"] #, "Tomato Paste"]
    assert_search "tomato", ["Tomatoes", "Tomato Sauce", "Tomato Paste"]
    assert_search "tomato paste", ["Tomato Paste"] #, "Tomatoes", "Tomato Sauce"]
  end

  def test_conversions_stemmed
    store [
      {name: "Tomato A", conversions: [{query: "tomato", count: 1}, {query: "tomatos", count: 1}, {query: "Tomatoes", count: 3}]},
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
    store_names ["Clorox Bleach", "Kroger Bleach", "Saran Wrap", "Kroger Plastic Wrap"]
    assert_search "clorox", ["Clorox Bleach", "Kroger Bleach"]
    assert_search "saran wrap", ["Saran Wrap", "Kroger Plastic Wrap"]
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

  protected

  def store(documents)
    documents.each do |document|
      $index.store document
    end
    $index.refresh
  end

  def store_names(names)
    store names.map{|name| {name: name} }
  end

  def assert_search(term, expected)
    search =
      Tire.search "products", type: "document" do
        searchkick_query ["name"], term
        explain true
      end

    assert_equal expected, search.results.map(&:name)
  end

end
