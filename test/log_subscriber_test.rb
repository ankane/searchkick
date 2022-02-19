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
