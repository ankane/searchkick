require 'searchkick/delayed_job/reindex_job'
require 'searchkick/backburner/reindex_job'

require_relative "test_helper"

class ReindexJobTest < Minitest::Test

  def setup
    super
    Searchkick.disable_callbacks
  end

  def teardown
    Searchkick.enable_callbacks
  end

  def test_create_delayed_job
    product = Product.create!(name: "Boom")
    Product.searchkick_index.refresh
    assert_search "*", []
    Searchkick::DelayedJob::ReindexJob.new("Product", product.id).perform
    Product.searchkick_index.refresh
    assert_search "*", ["Boom"]
  end

  def test_destroy_delayed_job
    product = Product.create!(name: "Boom")
    Product.reindex
    assert_search "*", ["Boom"]
    product.destroy
    Searchkick::DelayedJob::ReindexJob.new("Product", product.id).perform
    Product.searchkick_index.refresh
    assert_search "*", []
  end

  def test_create_backburner
    product = Product.create!(name: "Boom")
    Product.searchkick_index.refresh
    assert_search "*", []
    Searchkick::Backburner::ReindexJob.perform("Product", product.id)
    Product.searchkick_index.refresh
    assert_search "*", ["Boom"]
  end

  def test_destroy_backburner
    product = Product.create!(name: "Boom")
    Product.reindex
    assert_search "*", ["Boom"]
    product.destroy
    Searchkick::Backburner::ReindexJob.perform("Product", product.id)
    Product.searchkick_index.refresh
    assert_search "*", []
  end
end
