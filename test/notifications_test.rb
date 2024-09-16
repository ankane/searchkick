require_relative "test_helper"

class NotificationsTest < Minitest::Test
  def test_search
    Product.searchkick_index.refresh

    notifications = capture_notifications do
      Product.search("product").to_a
    end

    assert_equal 1, notifications.size
    assert_equal "search.searchkick", notifications.last[:name]
  end

  private

  def capture_notifications
    notifications = []
    callback = lambda do |name, started, finished, unique_id, payload|
      notifications << {name: name, payload: payload}
    end
    ActiveSupport::Notifications.subscribed(callback, /searchkick/) do
      yield
    end
    notifications
  end
end
