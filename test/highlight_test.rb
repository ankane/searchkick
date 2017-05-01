require_relative "test_helper"

class HighlightTest < Minitest::Test
  def test_basic
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <em>Cinema</em> Club", Product.search("cinema", fields: [:name], highlight: true).first.search_highlights[:name]
  end

  def test_tag
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <strong>Cinema</strong> Club", Product.search("cinema", fields: [:name], highlight: {tag: "<strong>"}).first.search_highlights[:name]
  end

  def test_tag_class
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <strong class='classy'>Cinema</strong> Club", Product.search("cinema", fields: [:name], highlight: {tag: "<strong class='classy'>"}).first.search_highlights[:name]
  end

  def test_multiple_fields
    store [{name: "Two Door Cinema Club", color: "Cinema Orange"}]
    highlights = Product.search("cinema", fields: [:name, :color], highlight: true).first.search_highlights
    assert_equal "Two Door <em>Cinema</em> Club", highlights[:name]
    assert_equal "<em>Cinema</em> Orange", highlights[:color]
  end

  def test_fields
    store [{name: "Two Door Cinema Club", color: "Cinema Orange"}]
    highlights = Product.search("cinema", fields: [:name, :color], highlight: {fields: [:name]}).first.search_highlights
    assert_equal "Two Door <em>Cinema</em> Club", highlights[:name]
    assert_nil highlights[:color]
  end

  def test_field_options
    store_names ["Two Door Cinema Club are a Northern Irish indie rock band"]
    fragment_size = ENV["MATCH"] == "word_start" ? 26 : 20
    assert_equal "Two Door <em>Cinema</em> Club are", Product.search("cinema", fields: [:name], highlight: {fields: {name: {fragment_size: fragment_size}}}).first.search_highlights[:name]
  end

  def test_multiple_words
    store_names ["Hello World Hello"]
    assert_equal "<em>Hello</em> World <em>Hello</em>", Product.search("hello", fields: [:name], highlight: true).first.search_highlights[:name]
  end

  def test_encoder
    store_names ["<b>Hello</b>"]
    assert_equal "&lt;b&gt;<em>Hello</em>&lt;&#x2F;b&gt;", Product.search("hello", fields: [:name], highlight: {encoder: "html"}, misspellings: false).first.search_highlights[:name]
  end

  def test_word_middle
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <em>Cinema</em> Club", Product.search("ine", fields: [:name], match: :word_middle, highlight: true).first.search_highlights[:name]
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
    assert_equal "Two Door <strong>Cinema</strong> Club", Product.search(body: body).first.search_highlights[:"name.analyzed"]
  end

  def test_legacy
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <em>Cinema</em> Club", Product.search("cinema", fields: [:name], highlight: true).with_details.first[1][:highlight][:name]
  end
end
