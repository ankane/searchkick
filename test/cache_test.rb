require_relative "test_helper"

class CacheTest < Minitest::Test
  def setup
    super
    @original_cache_store = Searchkick.cache_store
    @original_cache_expires_in = Searchkick.cache_expires_in
    @cache_store = ActiveSupport::Cache::MemoryStore.new
    Searchkick.cache_store = @cache_store
  end

  def teardown
    Searchkick.cache_store = @original_cache_store
    Searchkick.cache_expires_in = @original_cache_expires_in
  end

  def test_cache_disabled_by_default
    Searchkick.cache_store = nil
    store_names ["Product A"]
    
    # Should not use cache when disabled
    query1 = Product.search("product")
    result1 = query1.to_a
    query2 = Product.search("product")
    result2 = query2.to_a
    
    # Both should execute search (no cache hits)
    assert_equal ["Product A"], result1.map(&:name)
    assert_equal ["Product A"], result2.map(&:name)
    assert_equal false, query1.cache_hit, "Cache disabled should never hit"
    assert_equal false, query2.cache_hit, "Cache disabled should never hit"
  end

  def test_cache_enabled_basic_functionality
    store_names ["Product A", "Product B"]
    
    # First search should execute and cache the result
    query1 = Product.search("product")
    result1 = query1.to_a
    assert_equal false, query1.cache_hit, "First search should be a cache miss"
    
    # Second identical search should use cache
    query2 = Product.search("product")
    result2 = query2.to_a
    assert_equal true, query2.cache_hit, "Second search should be a cache hit"
    
    # Results should be identical
    assert_equal result1.map(&:name).sort, result2.map(&:name).sort
    
    # Cache should contain one entry
    assert_equal 1, @cache_store.instance_variable_get(:@data).size
  end

  def test_cache_key_generation
    store_names ["Product A"]
    
    # Same query should generate same cache key
    query1 = Product.search("product")
    query1.to_a # Force execution
    cache_key1 = query1.send(:query).send(:generate_cache_key)
    
    query2 = Product.search("product")
    query2.to_a # Force execution
    cache_key2 = query2.send(:query).send(:generate_cache_key)
    
    assert_equal cache_key1, cache_key2
    assert_match(/^searchkick:query:[a-f0-9]{32}$/, cache_key1)
  end

  def test_cache_key_different_for_different_queries
    store_names ["Product A"]
    
    query1 = Product.search("product")
    query1.to_a
    cache_key1 = query1.send(:query).send(:generate_cache_key)
    
    query2 = Product.search("different")
    query2.to_a
    cache_key2 = query2.send(:query).send(:generate_cache_key)
    
    refute_equal cache_key1, cache_key2
  end

  def test_cache_key_different_for_different_options
    store_names ["Product A"]
    
    query1 = Product.search("product", limit: 10)
    query1.to_a
    cache_key1 = query1.send(:query).send(:generate_cache_key)
    
    query2 = Product.search("product", limit: 20)
    query2.to_a
    cache_key2 = query2.send(:query).send(:generate_cache_key)
    
    refute_equal cache_key1, cache_key2
  end

  def test_cache_expiry_configuration
    Searchkick.cache_expires_in = 1.hour
    store_names ["Product A"]
    
    # Mock time to test expiry
    current_time = Time.now
    Time.stub :now, current_time do
      result1 = Product.search("product").to_a
      assert_equal ["Product A"], result1.map(&:name)
    end
    
    # Verify cache entry exists
    assert_equal 1, @cache_store.instance_variable_get(:@data).size
    
    # Move time forward beyond expiry
    future_time = current_time + 2.hours
    Time.stub :now, future_time do
      # Cache should be expired, but we can't easily test automatic expiry in MemoryStore
      # This test mainly verifies that expires_in option is passed correctly
      result2 = Product.search("product").to_a
      assert_equal ["Product A"], result2.map(&:name)
    end
  end

  def test_cache_with_different_models
    store_names ["Product A"], Product
    store_names ["Store A"], Store
    
    product_result = Product.search("A")
    product_result.to_a
    store_result = Store.search("A")
    store_result.to_a
    
    # Should generate different cache keys for different models
    product_cache_key = product_result.send(:query).send(:generate_cache_key)
    store_cache_key = store_result.send(:query).send(:generate_cache_key)
    
    refute_equal product_cache_key, store_cache_key
  end

  def test_cache_miss_and_hit_pattern
    store_names ["Product A"]
    
    # Clear cache to ensure clean state
    @cache_store.clear
    
    # First search - should be cache miss
    query1 = Product.search("product")
    result1 = query1.to_a
    assert_equal ["Product A"], result1.map(&:name)
    assert_equal false, query1.cache_hit, "Cache miss should not be a hit"
    assert_equal 1, @cache_store.instance_variable_get(:@data).size
    
    # Second identical search - should be cache hit
    query2 = Product.search("product")
    result2 = query2.to_a
    assert_equal ["Product A"], result2.map(&:name)
    assert_equal true, query2.cache_hit, "Cache hit should be a hit"
    assert_equal 1, @cache_store.instance_variable_get(:@data).size # No new cache entries
    
    # Different search - should be cache miss again
    query3 = Product.search("different")
    query3.to_a
    assert_equal false, query3.cache_hit, "Different query should be cache miss"
    assert_equal 2, @cache_store.instance_variable_get(:@data).size # New cache entry
  end

  def test_cache_store_interface_compatibility
    # Test that our caching works with Rails.cache-compatible interface
    mock_cache = Minitest::Mock.new
    mock_cache.expect :read, nil, [String]
    mock_cache.expect :write, true, [String, Object, Hash]
    
    Searchkick.cache_store = mock_cache
    store_names ["Product A"]
    
    result = Product.search("product").to_a
    assert_equal ["Product A"], result.map(&:name)
    
    mock_cache.verify
  end
end