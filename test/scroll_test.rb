require_relative "test_helper"

class ScrollTest < Minitest::Test
  def test_limit
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product A", "Product B"], order: {name: :asc}, limit: 2
  end

  def test_no_limit
    names = 20.times.map { |i| "Product #{i}" }
    store_names names
    assert_search "product", names
  end

  def test_offset
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product C", "Product D"], order: {name: :asc}, offset: 2, limit: 100
  end

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

  def test_kaminari
    skip unless defined?(Kaminari)

    require "action_view"

    I18n.load_path = Dir["test/support/kaminari.yml"]
    I18n.backend.load_translations

    view = ActionView::Base.new

    store_names ["Product A"]
    assert_equal "Displaying <b>1</b> product", view.page_entries_info(Product.search("product"))

    store_names ["Product B"]
    assert_equal "Displaying <b>all 2</b> products", view.page_entries_info(Product.search("product"))
  end
end
