require_relative "test_helper"

class SearchAsYouTypeTest < Minitest::Test
  def test_works
    with_options(Speaker, {search_as_you_type: true}) do
      # pp Speaker.search_index.mapping
      store_names ["Hummus"]
      assert_search "hum", ["Hummus"]
    end
  ensure
    Speaker.reindex
  end

  def default_model
    Speaker
  end
end
