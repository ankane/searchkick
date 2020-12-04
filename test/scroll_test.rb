require_relative "test_helper"

class ScrollTest < Minitest::Test
  def test_works
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E", "Product F"]
    products = Product.search("product", order: {name: :asc}, scroll: '1m', per_page: 2)
    assert_equal ["Product A", "Product B"], products.map(&:name)
    assert_equal "product", products.entry_name
    assert_equal 2, products.size
    assert_equal 2, products.length
    assert_equal 6, products.total_count
    assert_equal 6, products.total_entries
    assert products.any?

    # scroll for next 2
    products = products.scroll
    assert_equal ["Product C", "Product D"], products.map(&:name)

    # scroll for next 2
    products = products.scroll
    assert_equal ["Product E", "Product F"], products.map(&:name)

    # scroll exhausted
    products = products.scroll
    assert_equal [], products.map(&:name)
  end

  def test_body
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E", "Product F"]
    products = Product.search("product", body: {query: {match_all: {}}, sort: [{name: "asc"}]}, scroll: '1m', per_page: 2)
    assert_equal ["Product A", "Product B"], products.map(&:name)
    assert_equal "product", products.entry_name
    assert_equal 2, products.size
    assert_equal 2, products.length
    assert_equal 6, products.total_count
    assert_equal 6, products.total_entries
    assert products.any?

    # scroll for next 2
    products = products.scroll
    assert_equal ["Product C", "Product D"], products.map(&:name)

    # scroll for next 2
    products = products.scroll
    assert_equal ["Product E", "Product F"], products.map(&:name)

    # scroll exhausted
    products = products.scroll
    assert_equal [], products.map(&:name)
  end

  def test_all
    store_names ["Product A"]
    assert_equal ["Product A"], Product.search("*", scroll: "1m").map(&:name)
  end

  def test_no_option
    products = Product.search("*")
    error = assert_raises Searchkick::Error do
      products.scroll
    end
    assert_match(/Pass .+ option/, error.message)
  end

  def test_block
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E", "Product F"]
    batches_count = 0
    Product.search("*", scroll: "1m", per_page: 2).scroll do |batch|
      assert_equal 2, batch.size
      batches_count += 1
    end
    assert_equal 3, batches_count
  end
end
