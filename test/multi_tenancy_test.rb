require_relative "test_helper"

class MultiTenancyTest < Minitest::Test
  def setup
    skip unless defined?(Apartment)
  end

  def test_basic
    Apartment::Tenant.switch!("tenant1")
    store_names ["Product A"], Tenant
    Apartment::Tenant.switch!("tenant2")
    store_names ["Product B"], Tenant
    Apartment::Tenant.switch!("tenant1")
    assert_search "product", ["Product A"], {load: false}, Tenant
    Apartment::Tenant.switch!("tenant2")
    assert_search "product", ["Product B"], {load: false}, Tenant
  end

  def teardown
    Apartment::Tenant.reset if defined?(Apartment)
  end
end
