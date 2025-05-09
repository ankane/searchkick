require_relative "test_helper"

class QueryCrossClusterTest < Minitest::Test
  def test_cross_cluster_search_basic
    store_names ["Product A"]
    query = Product.search("product", ccs_clusters: ["cluster1", "cluster2"])
    assert_equal "products_test,cluster1:products_test,cluster2:products_test", query.params[:index]
  end

  def test_cross_cluster_search_basic_excluding_local_cluster
    store_names ["Product A"]
    query = Product.search("product", ccs_clusters: ["cluster1", "cluster2"], ccs_exclude_local: true)
    assert_equal "cluster1:products_test,cluster2:products_test", query.params[:index]
  end

  # We don't want to trigger an actual search here (requires complex cluster setup),
  # so simply instantiate a Searchkick::Query object and check the curl command
  def test_cross_cluster_search_endpoint
    store_names ["Product A"]
    query = Searchkick::Query.new(Product, "product", ccs_clusters: ["cluster1", "cluster2"])
    assert_includes CGI.unescape(query.to_curl), "/products_test,cluster1:products_test,cluster2:products_test/_search"
  end

  def test_cross_cluster_search_endpoint_excluding_local_cluster
    store_names ["Product A"]
    query = Searchkick::Query.new(Product, "product", ccs_clusters: ["cluster1", "cluster2"], ccs_exclude_local: true)
    assert_includes CGI.unescape(query.to_curl), "/cluster1:products_test,cluster2:products_test/_search"
  end

  def test_cross_cluster_search_multiple_indices
    store_names ["Product A"]
    query = Searchkick.search("product", models: [Product, Store], ccs_clusters: ["cluster1"])
    assert_equal "products_test,stores_test,cluster1:products_test,cluster1:stores_test", query.params[:index]
  end

  def test_cross_cluster_search_multiple_indices_excluding_local_cluster
    store_names ["Product A"]
    query = Searchkick.search("product", models: [Product, Store], ccs_clusters: ["cluster1"], ccs_exclude_local: true)
    assert_equal "cluster1:products_test,cluster1:stores_test", query.params[:index]
  end

  def test_cross_cluster_search_custom_index
    store_names ["Product A"]
    query = Product.search("product", index_name: "custom_index", ccs_clusters: ["cluster1"])
    assert_equal "custom_index,cluster1:custom_index", query.params[:index]
  end

  def test_cross_cluster_search_custom_index_excluding_local_cluster
    store_names ["Product A"]
    query = Product.search("product", index_name: "custom_index", ccs_clusters: ["cluster1"], ccs_exclude_local: true)
    assert_equal "cluster1:custom_index", query.params[:index]
  end

  def test_cross_cluster_search_empty_clusters
    store_names ["Product A"]
    query = Product.search("product", ccs_clusters: [])
    assert_equal "products_test", query.params[:index]
  end

  def test_cross_cluster_search_nil_clusters
    store_names ["Product A"]
    query = Product.search("product", ccs_clusters: nil)
    assert_equal "products_test", query.params[:index]
  end
end
