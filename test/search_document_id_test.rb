require_relative "test_helper"

class SearchDocumentIdTest < Minitest::Test
  def test_custom_search_document_id_with_find_by_search_document_ids
    skip "ActiveRecord only" if mongoid?

    # Define custom search_document_id on Product
    Product.class_eval do
      def search_document_id
        "custom_#{id}"
      end

      def self.find_by_search_document_ids(search_ids)
        ids = search_ids.map { |sid| sid.sub(/^custom_/, "") }
        where(id: ids)
      end
    end

    begin
      Product.reindex

      store_names ["Product A", "Product B"]

      # Test that search with load: true works
      results = Product.search("product").to_a
      assert_equal 2, results.size
      assert_kind_of Product, results.first
      assert_includes ["Product A", "Product B"], results.first.name
      assert_includes ["Product A", "Product B"], results.last.name
    ensure
      # Clean up - remove the custom methods
      Product.class_eval do
        undef_method :search_document_id if method_defined?(:search_document_id)

        class << self
          undef_method :find_by_search_document_ids if method_defined?(:find_by_search_document_ids)
        end
      end

      Product.reindex
    end
  end

  def test_custom_search_document_id_without_find_by_search_document_ids_shows_missing_records
    skip "ActiveRecord only" if mongoid?

    # Define custom search_document_id on Product but NOT find_by_search_document_ids
    Product.class_eval do
      def search_document_id
        "custom_#{id}"
      end
    end

    begin
      Product.reindex

      store_names ["Product A"]

      # Without find_by_search_document_ids, records should be reported as missing
      assert_warns "Records in search index do not exist in database" do
        results = Product.search("product").to_a
        assert_empty results
      end
    ensure
      # Clean up
      Product.class_eval do
        undef_method :search_document_id if method_defined?(:search_document_id)
      end

      Product.reindex
    end
  end
end
