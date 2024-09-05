require_relative "test_helper"

class PaginationTest < Minitest::Test
  def test_limit
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product A", "Product B"], order: {name: :asc}, limit: 2
    assert_order_relation ["Product A", "Product B"], Product.search("product").order(name: :asc).limit(2)
  end

  def test_no_limit
    names = 20.times.map { |i| "Product #{i}" }
    store_names names
    assert_search "product", names
  end

  def test_offset
    store_names ["Product A", "Product B", "Product C", "Product D"]
    assert_order "product", ["Product C", "Product D"], order: {name: :asc}, offset: 2, limit: 100
    assert_order_relation ["Product C", "Product D"], Product.search("product").order(name: :asc).offset(2).limit(100)
  end

  def test_pagination
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E", "Product F"]
    products = Product.search("product", order: {name: :asc}, page: 2, per_page: 2, padding: 1)
    assert_equal ["Product D", "Product E"], products.map(&:name)
    assert_equal "product", products.entry_name
    assert_equal 2, products.current_page
    assert_equal 1, products.padding
    assert_equal 2, products.per_page
    assert_equal 2, products.size
    assert_equal 2, products.length
    assert_equal 3, products.total_pages
    assert_equal 6, products.total_count
    assert_equal 6, products.total_entries
    assert_equal 2, products.limit_value
    assert_equal 3, products.offset_value
    assert_equal 3, products.offset
    assert_equal 3, products.next_page
    assert_equal 1, products.previous_page
    assert_equal 1, products.prev_page
    assert !products.first_page?
    assert !products.last_page?
    assert !products.empty?
    assert !products.out_of_range?
    assert products.any?
  end

  def test_relation
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E", "Product F"]
    products = Product.search("product", padding: 1).order(name: :asc).page(2).per_page(2)
    assert_equal ["Product D", "Product E"], products.map(&:name)
    assert_equal "product", products.entry_name
    assert_equal 2, products.current_page
    assert_equal 1, products.padding
    assert_equal 2, products.per_page
    assert_equal 2, products.size
    assert_equal 2, products.length
    assert_equal 3, products.total_pages
    assert_equal 6, products.total_count
    assert_equal 6, products.total_entries
    assert_equal 2, products.limit_value
    assert_equal 3, products.offset_value
    assert_equal 3, products.offset
    assert_equal 3, products.next_page
    assert_equal 1, products.previous_page
    assert_equal 1, products.prev_page
    assert !products.first_page?
    assert !products.last_page?
    assert !products.empty?
    assert !products.out_of_range?
    assert products.any?
  end

  def test_body
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E", "Product F"]
    products = Product.search("product", body: {query: {match_all: {}}, sort: [{name: "asc"}]}, page: 2, per_page: 2, padding: 1)
    assert_equal ["Product D", "Product E"], products.map(&:name)
    assert_equal "product", products.entry_name
    assert_equal 2, products.current_page
    assert_equal 1, products.padding
    assert_equal 2, products.per_page
    assert_equal 2, products.size
    assert_equal 2, products.length
    assert_equal 3, products.total_pages
    assert_equal 6, products.total_count
    assert_equal 6, products.total_entries
    assert_equal 2, products.limit_value
    assert_equal 3, products.offset_value
    assert_equal 3, products.offset
    assert_equal 3, products.next_page
    assert_equal 1, products.previous_page
    assert_equal 1, products.prev_page
    assert !products.first_page?
    assert !products.last_page?
    assert !products.empty?
    assert !products.out_of_range?
    assert products.any?
  end

  def test_nil_page
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E"]
    products = Product.search("product", order: {name: :asc}, page: nil, per_page: 2)
    assert_equal ["Product A", "Product B"], products.map(&:name)
    assert_equal 1, products.current_page
    assert products.first_page?
  end

  def test_strings
    store_names ["Product A", "Product B", "Product C", "Product D", "Product E", "Product F"]

    products = Product.search("product", order: {name: :asc}, page: "2", per_page: "2", padding: "1")
    assert_equal ["Product D", "Product E"], products.map(&:name)

    products = Product.search("product", order: {name: :asc}, limit: "2", offset: "3")
    assert_equal ["Product D", "Product E"], products.map(&:name)
  end

  def test_total_entries
    products = Product.search("product", total_entries: 4)
    assert_equal 4, products.total_entries
  end

  def test_kaminari
    require "action_view"

    I18n.load_path = Dir["test/support/kaminari.yml"]
    I18n.backend.load_translations

    view = ActionView::Base.new(ActionView::LookupContext.new([]), [], nil)

    store_names ["Product A"]
    assert_equal "Displaying <b>1</b> product", view.page_entries_info(Product.search("product"))

    store_names ["Product B"]
    assert_equal "Displaying <b>all 2</b> products", view.page_entries_info(Product.search("product"))

    store_names ["Product C"]
    assert_equal "Displaying products <b>1&nbsp;-&nbsp;2</b> of <b>3</b> in total", view.page_entries_info(Product.search("product").per_page(2))
  end

  def test_deep_paging
    with_options({deep_paging: true}, Song) do
      assert_empty Song.search("*", offset: 10000, limit: 1).to_a
    end
  end

  def test_no_deep_paging
    Song.reindex
    error = assert_raises(Searchkick::InvalidQueryError) do
      Song.search("*", offset: 10000, limit: 1).to_a
    end
    assert_match "Result window is too large", error.message
  end

  def test_max_result_window
    Song.delete_all
    with_options({max_result_window: 10000}, Song) do
      relation = Song.search("*", offset: 10000, limit: 1)
      assert_empty relation.to_a
      assert_equal 1, relation.per_page
      assert_equal 0, relation.total_pages
    end
  end

  def test_search_after
    store_names ["Product A", "Product B", "Product C", "Product D"]
    # ensure different created_at
    store_names ["Product B"]

    options = {order: {name: :asc, created_at: :asc}, per_page: 2}

    products = Product.search("product", **options)
    assert_equal ["Product A", "Product B"], products.map(&:name)

    search_after = products.hits.last["sort"]
    products = Product.search("product", body_options: {search_after: search_after}, **options)
    assert_equal ["Product B", "Product C"], products.map(&:name)

    search_after = products.hits.last["sort"]
    products = Product.search("product", body_options: {search_after: search_after}, **options)
    assert_equal ["Product D"], products.map(&:name)
  end

  def test_pit
    skip unless pit_supported?

    store_names ["Product A", "Product B", "Product D", "Product E", "Product G"]

    pit_id =
      if Searchkick.opensearch?
        path = "#{CGI.escape(Product.searchkick_index.name)}/_search/point_in_time"
        Searchkick.client.transport.perform_request("POST", path, {keep_alive: "5s"}).body["pit_id"]
      else
        Searchkick.client.open_point_in_time(index: Product.searchkick_index.name, keep_alive: "5s")["id"]
      end

    store_names ["Product C", "Product F"]

    options = {
      order: {name: :asc},
      per_page: 2,
      body_options: {pit: {id: pit_id}},
      index_name: ""
    }

    products = Product.search("product", **options)
    assert_equal ["Product A", "Product B"], products.map(&:name)

    products = Product.search("product", page: 2, **options)
    assert_equal ["Product D", "Product E"], products.map(&:name)

    products = Product.search("product", page: 3, **options)
    assert_equal ["Product G"], products.map(&:name)

    products = Product.search("product", page: 4, **options)
    assert_empty products.map(&:name)

    if Searchkick.opensearch?
      Searchkick.client.transport.perform_request("DELETE", "_search/point_in_time", {}, {pit_id: pit_id})
    else
      Searchkick.client.close_point_in_time(body: {id: pit_id})
    end

    error = assert_raises do
      Product.search("product", **options).load
    end
    assert_match "No search context found for id", error.message
  end

  private

  def pit_supported?
    Searchkick.opensearch? ? !Searchkick.server_below?("2.4.0", true) : !Searchkick.server_below?("7.10.0")
  end
end
