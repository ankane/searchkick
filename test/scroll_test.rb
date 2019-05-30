require_relative "test_helper"

class ScrollTest < Minitest::Test
  def test_scroll
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E", "Product F"]
    products = Product.search("product", order: {name: :asc}, scroll: '1m', per_page: 2)
    assert_equal ["Product A", "Product B"], products.map(&:name)
    assert_equal "product", products.entry_name
    assert_equal "1m", products.options[:scroll]
    assert_equal products.response["_scroll_id"], products.scroll_id
    assert_equal 2, products.size
    assert_equal 2, products.length
    assert_equal 6, products.total_count
    assert_equal 6, products.total_entries
    assert products.any?

    # scroll for next 2
    products = products.scroll
    assert_equal ["Product C", "Product D"], products.map(&:name)
    assert_equal "product", products.entry_name
    # scroll for next 2
    products = products.scroll
    assert_equal ["Product E", "Product F"], products.map(&:name)
    assert_equal "product", products.entry_name
    # scroll exhausted
    products = products.scroll
    assert_equal [], products.map(&:name)
    assert_equal "product", products.entry_name
  end

  def test_scroll_body
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E", "Product F"]
    products = Product.search("product", body: {query: {match_all: {}}, sort: [{name: "asc"}]}, scroll: '1m', per_page: 2)
    assert_equal ["Product A", "Product B"], products.map(&:name)
    assert_equal "product", products.entry_name
    assert_equal "1m", products.options[:scroll]
    assert_equal products.response["_scroll_id"], products.scroll_id
    assert_equal 2, products.size
    assert_equal 2, products.length
    assert_equal 6, products.total_count
    assert_equal 6, products.total_entries
    assert products.any?

    # scroll for next 2
    products = products.scroll
    assert_equal ["Product C", "Product D"], products.map(&:name)
    assert_equal "product", products.entry_name
    # scroll for next 2
    products = products.scroll
    assert_equal ["Product E", "Product F"], products.map(&:name)
    assert_equal "product", products.entry_name
    # scroll exhausted
    products = products.scroll
    assert_equal [], products.map(&:name)
    assert_equal "product", products.entry_name
  end
end
