class Minitest::Test
  include ActiveJob::TestHelper

  def setup
    $setup_once ||= begin
      # TODO improve
      Product.searchkick_index.delete if Product.searchkick_index.exists?
      Product.reindex
      Product.reindex # run twice for both index paths
      Product.create!(name: "Set mapping")

      Store.reindex
      Animal.reindex
    end

    Product.destroy_all
    Store.destroy_all
    Animal.destroy_all
  end

  protected

  def setup_region
    $setup_region ||= (Region.reindex || true)
    Region.destroy_all
  end

  def setup_speaker
    $setup_speaker ||= (Speaker.reindex || true)
    Speaker.destroy_all
  end

  def store(documents, model = default_model, reindex: true)
    if reindex
      documents.shuffle.each do |document|
        model.create!(document)
      end
      model.searchkick_index.refresh
    else
      Searchkick.callbacks(false) do
        documents.shuffle.each do |document|
          model.create!(document)
        end
      end
    end
  end

  def store_names(names, model = default_model, reindex: true)
    store names.map { |name| {name: name} }, model, reindex: reindex
  end

  # no order
  def assert_search(term, expected, options = {}, model = default_model)
    assert_equal expected.sort, model.search(term, **options).map(&:name).sort
  end

  def assert_order(term, expected, options = {}, model = default_model)
    assert_equal expected, model.search(term, **options).map(&:name)
  end

  def assert_equal_scores(term, options = {}, model = default_model)
    assert_equal 1, model.search(term, **options).hits.map { |a| a["_score"] }.uniq.size
  end

  def assert_first(term, expected, options = {}, model = default_model)
    assert_equal expected, model.search(term, **options).map(&:name).first
  end

  def assert_misspellings(term, expected, misspellings = {}, model = default_model)
    options = {
      fields: [:name, :color],
      misspellings: misspellings
    }
    assert_search(term, expected, options, model)
  end

  def assert_warns(message)
    _, stderr = capture_io do
      yield
    end
    assert_match "[searchkick] WARNING: #{message}", stderr
  end

  def with_options(options, model = default_model)
    previous_options = model.searchkick_options.dup
    begin
      model.searchkick_options.merge!(options)
      model.reindex
      yield
    ensure
      model.searchkick_options.clear
      model.searchkick_options.merge!(previous_options)
    end
  end

  def activerecord?
    defined?(ActiveRecord)
  end

  def mongoid?
    defined?(Mongoid)
  end

  def default_model
    Product
  end

  def ci?
    ENV["CI"]
  end

  # for Active Job helpers
  def tagged_logger
  end
end
