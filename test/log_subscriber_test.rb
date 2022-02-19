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
      product.update!(name: "Product B")
    end
    assert_match "Product Store", output
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
    Product.create!(name: "Product A")
    output = capture_logs do
      Product.reindex
    end
    assert_match "Product Import", output
    assert_match '"count":1', output
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
      output
    ensure
      ActiveSupport::LogSubscriber.logger = previous_logger
    end
  end
end
