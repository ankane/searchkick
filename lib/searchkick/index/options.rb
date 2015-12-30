require "searchkick/index/settings_builder"

module Searchkick
  class Index
    module Options
      def index_options
        language = options[:language]
        language = language.call if language.respond_to?(:call)

        if options[:mappings] && !options[:merge_mappings]
          settings = options[:settings] || {}
          mappings = options[:mappings]
        else
          settings = Searchkick::Index::SettingsBuilder.new(options)

          settings.deep_merge_user_settings
          settings.set_similarity if options[:similarity]
          settings.set_synonyms if settings.synonyms.any?
          settings.set_wordnet if options[:wordnet]
          settings.delete_asciifolding_filter if options[:special_characters] == false

          mapping = {}

          # conversions
          if (conversions_field = options[:conversions])
            mapping[conversions_field] = {
              type: "nested",
              properties: {
                query: {type: "string", analyzer: "searchkick_keyword"},
                count: {type: "integer"}
              }
            }
          end

          mapping_options = Hash[
            [:autocomplete, :suggest, :word, :text_start, :text_middle, :text_end, :word_start, :word_middle, :word_end, :highlight, :searchable, :only_analyzed]
              .map { |type| [type, map_to_string(options[type])] }
          ]

          word = options[:word] != false && (!options[:match] || options[:match] == :word)

          mapping_options.values.flatten.uniq.each do |field|
            field_mapping = {
              type: "multi_field",
              fields: {}
            }

            unless mapping_options[:only_analyzed].include?(field)
              field_mapping[:fields][field] = {type: "string", index: "not_analyzed"}
            end

            if !options[:searchable] || mapping_options[:searchable].include?(field)
              if word
                field_mapping[:fields]["analyzed"] = {type: "string", index: "analyzed"}

                if mapping_options[:highlight].include?(field)
                  field_mapping[:fields]["analyzed"][:term_vector] = "with_positions_offsets"
                end
              end

              mapping_options.except(:highlight, :searchable, :only_analyzed).each do |type, fields|
                if options[:match] == type || fields.include?(field)
                  field_mapping[:fields][type] = {type: "string", index: "analyzed", analyzer: "searchkick_#{type}_index"}
                end
              end
            end

            mapping[field] = field_mapping
          end

          map_to_string(options[:locations]).each do |field|
            mapping[field] = {
              type: "geo_point"
            }
          end

          map_to_string(options[:unsearchable]).each do |field|
            mapping[field] = {
              type: "string",
              index: "no"
            }
          end

          if options[:routing]
            routing = { required: true, path: options[:routing].to_s }
          else
            routing = {}
          end

          dynamic_fields = {
            # analyzed field must be the default field for include_in_all
            # http://www.elasticsearch.org/guide/reference/mapping/multi-field-type/
            # however, we can include the not_analyzed field in _all
            # and the _all index analyzer will take care of it
            "{name}" => {type: "string", index: "not_analyzed", include_in_all: !options[:searchable]}
          }

          unless options[:searchable]
            if options[:match] && options[:match] != :word
              dynamic_fields[options[:match]] = {type: "string", index: "analyzed", analyzer: "searchkick_#{options[:match]}_index"}
            end

            if word
              dynamic_fields["analyzed"] = {type: "string", index: "analyzed"}
            end
          end

          mappings = {
            _default_: {
              properties: mapping,
              _routing: routing,
              # https://gist.github.com/kimchy/2898285
              dynamic_templates: [
                {
                  string_template: {
                    match: "*",
                    match_mapping_type: "string",
                    mapping: {
                      # http://www.elasticsearch.org/guide/reference/mapping/multi-field-type/
                      type: "multi_field",
                      fields: dynamic_fields
                    }
                  }
                }
              ]
            }
          }.deep_merge(options[:mappings] || {})
        end

        {
          settings: settings.output,
          mappings: mappings
        }
      end


    end
  end
end
