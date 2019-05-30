require_relative "test_helper"

class ScrollTest < Minitest::Test
  def test_scroll
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E", "Product F"]
    products = Product.search("product", order: {name: :asc}, scroll: '1m', per_page: 2)
    assert_equal ["Product A", "Product B"], products.map(&:name)
    assert_equal "product", products.entry_name
    assert_equal "1m", products.options[:scroll]
    assert_equal products.response["_scroll_id"], products.scroll_id
    assert_nil products.current_page
    assert_nil products.padding
    assert_nil products.per_page
    assert_equal 2, products.size
    assert_equal 2, products.length
    assert_nil products.total_pages
    assert_equal 6, products.total_count
    assert_equal 6, products.total_entries
    assert_nil products.limit_value
    assert_nil products.offset_value
    assert_nil products.offset
    assert_nil products.next_page
    assert_nil products.previous_page
    assert_nil products.prev_page
    assert !products.first_page?
    assert !products.last_page?
    assert !products.empty?
    assert !products.out_of_range?
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
    assert_nil products.current_page
    assert_nil products.padding
    assert_nil products.per_page
    assert_equal 2, products.size
    assert_equal 2, products.length
    assert_nil products.total_pages
    assert_equal 6, products.total_count
    assert_equal 6, products.total_entries
    assert_nil products.limit_value
    assert_nil products.offset_value
    assert_nil products.offset
    assert_nil products.next_page
    assert_nil products.previous_page
    assert_nil products.prev_page
    assert !products.first_page?
    assert !products.last_page?
    assert !products.empty?
    assert !products.out_of_range?
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

  def test_scroll_nil_scroll
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E"]
    products = Product.search("product", order: {name: :asc}, scroll: nil, per_page: 2)
    assert_equal ["Product A", "Product B"], products.map(&:name)
    assert_equal 1, products.current_page
    assert products.first_page?
    assert_nil products.options[:scroll]
    assert_nil products.scroll_id
  end
end
