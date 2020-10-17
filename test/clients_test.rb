require_relative "test_helper"

class ClientsTest < Minitest::Test

  def setup
    @default_client_was = Searchkick.client
  end

  def teardown
    Searchkick.client = @default_client_was
  end

  def test_default_client
    assert_kind_of Searchkick::Client, Searchkick.client
  end

  def test_setter
    Searchkick.client = 'foobar'
    assert_equal 'foobar', Searchkick.client
  end

  def test_custom_client
    Searchkick.add_client(:custom, url: 'http://custom:9200')
    assert_equal 'custom', Searchkick.client(:custom).host.fetch(:host)
  end
end
