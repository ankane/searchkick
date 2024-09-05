require_relative "test_helper"

class LogSubscriberTest < Minitest::Test
  def test_create
    output = capture_logs do
      Product.create!(name: "Product A")
    end
    assert_match "Product Store", output
  end

  def test_update
    product = Product.create!(name: "Product A")
    output = capture_logs do
      product.reindex(:search_name)
    end
    assert_match "Product Update", output
  end

  def test_destroy
    product = Product.create!(name: "Product A")
    output = capture_logs do
      product.destroy
    end
    assert_match "Product Remove", output
  end

  def test_bulk
    output = capture_logs do
      Searchkick.callbacks(:bulk) do
        Product.create!(name: "Product A")
      end
    end
    assert_match "Bulk", output
    refute_match "Product Store", output
  end

  def test_reindex
    create_products
    output = capture_logs do
      Product.reindex
    end
    assert_match "Product Import", output
    assert_match '"count":3', output
  end

  def test_reindex_relation
    products = create_products
    output = capture_logs do
      Product.where.not(id: products.last.id).reindex
    end
    assert_match "Product Import", output
    assert_match '"count":2', output
  end

  def test_search
    output = capture_logs do
      Product.search("product").to_a
    end
    assert_match "Product Search", output
  end

  def test_multi_search
    output = capture_logs do
      Searchkick.multi_search([Product.search("product")])
    end
    assert_match "Multi Search", output
  end

  private

  def create_products
    Searchkick.callbacks(false) do
      3.times.map do
        Product.create!(name: "Product A")
      end
    end
  end

  def capture_logs
    previous_logger = ActiveSupport::LogSubscriber.logger
    io = StringIO.new
    begin
      ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(io)
      yield
      io.rewind
      output = io.read
      previous_logger.debug(output) if previous_logger
      puts output if ENV["LOG_SUBSCRIBER"]
      output
    ensure
      ActiveSupport::LogSubscriber.logger = previous_logger
    end
  end
end
