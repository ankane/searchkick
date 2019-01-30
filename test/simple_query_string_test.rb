require_relative "test_helper"

class SimpleQueryStringTest < Minitest::Test
  def test_simple_query_string_query_body
    store_names ["Milk", "Apple Juice", "Juice"]

    query = Product.search("apple +juice | milk", simple_query_string: true, execute: false)

    expected_query = {
      simple_query_string: {
        query: "apple +juice | milk",
        default_operator: "and",
        fields: ["*.analyzed"],
        analyze_wildcard:true
        }
      }

    assert_equal expected_query, query.body[:query]
  end

  def test_and
    store_names ["Milk", "Apple Juice", "Juice"]
    results = Product.search("apple +juice", simple_query_string: true)

    assert_equal ["Apple Juice"], results.map(&:name)
  end

  def test_or
    store_names ["Milk", "Apple Juice", "Juice"]
    results = Product.search("apple | juice", simple_query_string: true)

    assert_equal ["Apple Juice", "Juice"], results.map(&:name).sort
  end

  def test_and_or
    store_names ["Milk", "Apple Juice", "Juice"]
    results = Product.search("apple + juice | milk", simple_query_string: true)

    assert_equal ["Apple Juice", "Milk"], results.map(&:name).sort
  end

  def test_exclude
    store_names ["Milk", "Apple Juice", "Juice"]
    results = Product.search("juice | milk -apple", simple_query_string: true)

    assert_equal ["Juice", "Milk"], results.map(&:name).sort
  end

  def test_with_order
    store_names ["Milk", "Apple Juice", "Juice"]
    results = Product.search("apple | juice", simple_query_string: true, order: { name: :asc })

    assert_equal ["Apple Juice", "Juice"], results.map(&:name)

    results = Product.search("apple | juice", simple_query_string: true, order: { name: :desc })

    assert_equal ["Juice", "Apple Juice"], results.map(&:name)
  end

  def test_with_pagination
    store_names ["Milk", "Apple Juice", "Juice"]

    results = Product.search("apple + juice | milk", simple_query_string: true, limit: 1, order: { name: :desc })

    assert_equal ["Milk"], results.map(&:name)

    results = Product.search("apple + juice | milk", simple_query_string: true, limit: 1, page: 2, order: { name: :desc })

    assert_equal ["Apple Juice"], results.map(&:name)
  end
end
