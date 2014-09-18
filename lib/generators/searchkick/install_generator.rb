require 'rails/generators'
require 'rails/generators/base'

module Searchkick
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      def copy_initializer
        template "searchkick.rb", "config/initializers/searchkick.rb"
      end

    end
  end
end
