require_relative "test_helper"

class ModelTest < Minitest::Test
  def test_search_relation
    _, stderr = capture_io { Product.search("*") }
    assert_equal "", stderr
    _, stderr = capture_io { Product.all.search("*") }
    assert_match "WARNING", stderr
  end

  def test_search_relation_default_scope
    Band.reindex

    _, stderr = capture_io { Band.search("*") }
    assert_equal "", stderr
    _, stderr = capture_io { Band.all.search("*") }
    assert_match "WARNING", stderr
  end
end
