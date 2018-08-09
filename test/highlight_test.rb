require_relative "test_helper"

class HighlightTest < Minitest::Test
  def test_basic
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <em>Cinema</em> Club", Product.search("cinema", highlight: true).highlights.first[:name]
  end

  def test_with_highlights
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <em>Cinema</em> Club", Product.search("cinema", highlight: true).with_highlights.first.last[:name]
  end

  def test_tag
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <strong>Cinema</strong> Club", Product.search("cinema", highlight: {tag: "<strong>"}).highlights.first[:name]
  end

  def test_tag_class
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <strong class='classy'>Cinema</strong> Club", Product.search("cinema", highlight: {tag: "<strong class='classy'>"}).highlights.first[:name]
  end

  def test_very_long
    store_names [("Two Door Cinema Club " * 100).strip]
    assert_equal ("Two Door <em>Cinema</em> Club " * 100).strip, Product.search("cinema", highlight: true).highlights.first[:name]
  end

  def test_multiple_fields
    store [{name: "Two Door Cinema Club", color: "Cinema Orange"}]
    highlights = Product.search("cinema", fields: [:name, :color], highlight: true).highlights.first
    assert_equal "Two Door <em>Cinema</em> Club", highlights[:name]
    assert_equal "<em>Cinema</em> Orange", highlights[:color]
  end

  def test_fields
    store [{name: "Two Door Cinema Club", color: "Cinema Orange"}]
    highlights = Product.search("cinema", fields: [:name, :color], highlight: {fields: [:name]}).highlights.first
    assert_equal "Two Door <em>Cinema</em> Club", highlights[:name]
    assert_nil highlights[:color]
  end

  def test_field_options
    store_names ["Two Door Cinema Club are a Northern Irish indie rock band"]
    fragment_size = ENV["MATCH"] == "word_start" ? 26 : 21
    assert_equal "Two Door <em>Cinema</em> Club are", Product.search("cinema", highlight: {fields: {name: {fragment_size: fragment_size}}}).highlights.first[:name]
  end

  def test_multiple_words
    store_names ["Hello World Hello"]
    assert_equal "<em>Hello</em> World <em>Hello</em>", Product.search("hello", highlight: true).highlights.first[:name]
  end

  def test_encoder
    store_names ["<b>Hello</b>"]
    assert_equal "&lt;b&gt;<em>Hello</em>&lt;&#x2F;b&gt;", Product.search("hello", highlight: {encoder: "html"}, misspellings: false).highlights.first[:name]
  end

  def test_word_middle
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <em>Cinema</em> Club", Product.search("ine", match: :word_middle, highlight: true).highlights.first[:name]
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
    assert_equal "Two Door <strong>Cinema</strong> Club", Product.search(body: body).highlights.first[:"name.analyzed"]
  end

  def test_multiple_highlights
    store_names ["Two Door Cinema Club Some Other Words And Much More Doors Cinema Club"]
    highlights = Product.search("cinema", highlight: {fragment_size: 20}).highlights(multiple: true).first[:name]
    assert highlights.is_a?(Array)
    assert_equal highlights.count, 2
    refute_equal highlights.first, highlights.last
    highlights.each do |highlight|
      assert highlight.include?("<em>Cinema</em>")
    end
  end

  def test_search_highlights_method
    store_names ["Two Door Cinema Club"]
    assert_equal "Two Door <em>Cinema</em> Club", Product.search("cinema", highlight: true).first.search_highlights[:name]
  end

  def test_match_all
    store_names ["Two Door Cinema Club"]
    assert_nil Product.search("*", highlight: true).highlights.first[:name]
  end

  def test_match_all_load_false
    store_names ["Two Door Cinema Club"]
    assert_nil Product.search("*", highlight: true, load: false).highlights.first[:name]
  end

  def test_match_all_search_highlights
    store_names ["Two Door Cinema Club"]
    assert_nil Product.search("*", highlight: true).first.search_highlights[:name]
  end
end
