# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Searchkick
  class MigrationGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration
    source_root File.expand_path("templates", __dir__)
    desc "Installs searchkick migration file."

    def install
      migration_template(
        "migration.rb.erb",
        "db/migrate/create_searchkick_tables.rb",
        migration_version: migration_version,
      )
    end

    def self.next_migration_number(dirname)
      ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    private

    def migration_version
      "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
    end
  end
end
