require "searchkick/index/settings_builder"
require "searchkick/index/mapping_builder"

module Searchkick
  class Index
    module Options
      def index_options
        if options[:mappings] && !options[:merge_mappings]
          settings = options[:settings] || {}
          mappings = options[:mappings]
        else
          settings_builder = Searchkick::Index::SettingsBuilder.new(options)
          mapping_builder = Searchkick::Index::MappingBuilder.new(options)

          settings_builder.deep_merge_user_settings
          settings_builder.set_similarity if options[:similarity]
          settings_builder.set_synonyms if settings_builder.synonyms.any?
          settings_builder.set_wordnet if options[:wordnet]
          settings_builder.delete_asciifolding_filter if options[:special_characters] == false

          mapping_builder.set_conversion_field if options[:conversions]
          mapping_builder.set_field_mapping
          mapping_builder.set_locations
          mapping_builder.set_unsearchable
          mapping_builder.set_dynamic_fields if !options[:searchable]

          settings = settings_builder.output
          mappings = mapping_builder.output
        end

        {
          settings: settings,
          mappings: mappings
        }
      end
    end
  end
end
