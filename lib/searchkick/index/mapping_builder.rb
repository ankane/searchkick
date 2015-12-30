module Searchkick
  class Index
    class MappingBuilder
      include Searchkick::Helpers
      attr_reader :options, :mapping, :mapping_options

      def initialize(options)
        @options = options
        @mapping = {}
        @mapping_options = Hash[
            [:autocomplete, :suggest, :word, :text_start, :text_middle, :text_end, :word_start, :word_middle, :word_end, :highlight, :searchable, :only_analyzed]
              .map { |type| [type, map_to_string(options[type])] }
          ]
      end

      def output
        {
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

      def set_conversion_field
        conversions_field = options[:conversions]
        mapping[conversions_field] = {
          type: "nested",
          properties: {
            query: {type: "string", analyzer: "searchkick_keyword"},
            count: {type: "integer"}
          }
        }
      end

      def set_field_mapping
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
      end

      def set_dynamic_fields
        if options[:match] && options[:match] != :word
          dynamic_fields[options[:match]] = {type: "string", index: "analyzed", analyzer: "searchkick_#{options[:match]}_index"}
        end

        if word
          dynamic_fields["analyzed"] = {type: "string", index: "analyzed"}
        end
      end

      def set_locations
        map_to_string(options[:locations]).each do |field|
          mapping[field] = {
            type: "geo_point"
          }
        end
      end

      def set_unsearchable
        map_to_string(options[:unsearchable]).each do |field|
          mapping[field] = {
            type: "string",
            index: "no"
          }
        end
      end

      private

      def dynamic_fields
        {
          # analyzed field must be the default field for include_in_all
          # http://www.elasticsearch.org/guide/reference/mapping/multi-field-type/
          # however, we can include the not_analyzed field in _all
          # and the _all index analyzer will take care of it
          "{name}" => {type: "string", index: "not_analyzed", include_in_all: !options[:searchable]}
        }
      end

      def word
        options[:word] != false && (!options[:match] || options[:match] == :word)
      end

      def routing
        if options[:routing]
          { required: true, path: options[:routing].to_s }
        else
          {}
        end
      end
    end
  end
end
