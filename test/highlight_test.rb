require_relative "test_helper"

class HighlightTest < Minitest::Test
  def test_basic
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <em>Cinema</em> Club", Product.search("cinema", fields: [:name], highlight: true).with_details.first[1][:highlight][:name]
  end

  def test_tag
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <strong>Cinema</strong> Club", Product.search("cinema", fields: [:name], highlight: {tag: "<strong>"}).with_details.first[1][:highlight][:name]
  end

  def test_multiple_fields
    store [{name: "Two Door Cinema Club", color: "Cinema Orange"}]
    highlight = Product.search("cinema", fields: [:name, :color], highlight: true).with_details.first[1][:highlight]
    assert_equal "Two Door <em>Cinema</em> Club", highlight[:name]
    assert_equal "<em>Cinema</em> Orange", highlight[:color]
  end

  def test_fields
    store [{name: "Two Door Cinema Club", color: "Cinema Orange"}]
    highlight = Product.search("cinema", fields: [:name, :color], highlight: {fields: [:name]}).with_details.first[1][:highlight]
    assert_equal "Two Door <em>Cinema</em> Club", highlight[:name]
    assert_nil highlight[:color]
  end

  def test_field_options
    store_names ["Two Door Cinema Club are a Northern Irish indie rock band"]
    fragment_size = ENV["MATCH"] == "word_start" ? 26 : 20
    assert_equal "Two Door <em>Cinema</em> Club are", Product.search("cinema", fields: [:name], highlight: {fields: {name: {fragment_size: fragment_size}}}).with_details.first[1][:highlight][:name]
  end

  def test_multiple_words
    store_names ["Hello World Hello"]
    assert_equal "<em>Hello</em> World <em>Hello</em>", Product.search("hello", fields: [:name], highlight: true).with_details.first[1][:highlight][:name]
  end

  def test_encoder
    store_names ["<b>Hello</b>"]
    assert_equal "&lt;b&gt;<em>Hello</em>&lt;&#x2F;b&gt;", Product.search("hello", fields: [:name], highlight: {encoder: "html"}, misspellings: false).with_details.first[1][:highlight][:name]
  end

  def test_body
    skip if ENV["MATCH"] == "word_start"
    store_names ["Two Door Cinema Club"]
    body = {
      query: {
        match: {
          "name.analyzed" => "cinema"
        }
      },
      highlight: {
        pre_tags: ["<strong>"],
        post_tags: ["</strong>"],
        fields: {
          "name.analyzed" => {}
        }
      }
    }
    assert_equal "Two Door <strong>Cinema</strong> Club", Product.search(body: body).with_details.first[1][:highlight][:"name.analyzed"]
  end
end
