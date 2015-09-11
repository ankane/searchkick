# encoding: utf-8

require_relative "test_helper"

class String
  def contains_word?(phrase)
     (self =~ /\b#{phrase}\b/i) != nil
  end
end

class TestPhrase < Minitest::Test

  # contains_word?

  def test_contains_word
    phrase = "simon jumps over the moon"
    assert phrase.contains_word?("jumps"), "central word"
    assert phrase.contains_word?("simon"), "first word"
    assert phrase.contains_word?("moon"), "last word"
    assert phrase.contains_word?("Moon"), "capital letter should pass"
    assert phrase.contains_word?("the moon") , "multiple words acceptable"
    assert !phrase.contains_word?("ver"), "missing first character"
    assert !phrase.contains_word?("ove"), "missing last character"
    assert !phrase.contains_word?("ve"), "missing first and last character"
    assert !phrase.contains_word?("milk"), "missing word"
    assert phrase.contains_word?("over") && phrase.contains_word?("moon"), "all words"
    assert phrase.contains_word?("over") || phrase.contains_word?("sun"), "any words"
  end

  def seed_database
    @phrases = ["Whole Homogenised Pasteurised Cows Milk", #0
                "Half-fat Homogenised Pasteurised Cows Milk", #1
                "Whole Unhomogenised Unpasteurised Cows Milk", #2
                "Whole Homogenised Pasteurised Goats Milk", #3
                "Whole Ice Homogenised Pasteurised Goats Cream", #4
                "Whole Homogenised Pasteurised Goats Ice Cream"] #5
    store_names @phrases    
  end

  def test_all_words
    seed_database
    assert_search "ice cream", @phrases.select { |p|
      p.contains_word?('ice') && p.contains_word?('cream')
    }
  end

  def test_any_words
    seed_database
    assert_search "cows cream", @phrases.select { |p|
       p.contains_word?("cows") || p.contains_word?("cream")
    }, {operator: :or}
  end

  def test_phrase_nothing_returned
    seed_database
    assert_search "cream goats", [], match_phrase: true
  end

  def test_phrase
    seed_database
    assert_search "ice cream", @phrases.select { |p|
      p.contains_word?('ice cream')
    }, match_phrase: true
  end

  def test_phrase_false
    seed_database
    assert_search "cream goats", @phrases.select { |p|
      p.contains_word?('cream') && p.contains_word?('goats')
    }, match_phrase: false
  end

  def test_phrase_misspelled
    seed_database
    assert_search "ice creem", @phrases.select { |p|
      p.contains_word?('ice cream')
    }, match_phrase: true
  end

  def test_phrase_not_misspelled
    seed_database
    assert_search "ice creem", [], {match_phrase: true,  misspellings: false}
  end


end
