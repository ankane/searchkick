module Searchkick
  class IndexVersion < ::ActiveRecord::Base
    INITIAL_VERSION = 10_000
    self.table_name = 'searchkick_index_versions'

    class << self
      def bump_versions(model, ids)
        create_if_missing(model, ids)

        # Need to be inside transaction in order to utilize implicit pessimistic lock
        # applied by Postgres to updated version records.
        # There is no any need to ask for `requires_new: true`.
        transaction do
          new_versions = update_versions(model, ids)
          yield new_versions
        end
      end

      private

      def create_if_missing(model, ids)
        new_records_attributes = ids.map { |id|
          {
            resource_type: model.name,
            resource_id: id,
            version: INITIAL_VERSION
          }
        }

        insert_all(new_records_attributes)
      end

      def update_versions(model, ids)
        quoted_ids = ids.map { |id| connection.quote(id) }.join(',')

        result_sets = connection.execute <<~SQL
          UPDATE #{table_name}
          SET version = GREATEST(version, #{INITIAL_VERSION}) + 1
          WHERE resource_type = #{connection.quote(model.name)}
            AND resource_id IN (#{quoted_ids})
          RETURNING resource_id, version
        SQL

        result_sets.map { |rs| rs.values_at('resource_id', 'version') }.to_h
      end
    end
  end
end
