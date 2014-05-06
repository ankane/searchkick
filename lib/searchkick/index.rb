module Searchkick
  class Index
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def create(options = {})
      client.indices.create index: name, body: options
    end

    def delete
      client.indices.delete index: name
    end

    def exists?
      client.indices.exists index: name
    end

    def refresh
      client.indices.refresh index: name
    end

    def store(record)
      client.index(
        index: name,
        type: document_type(record),
        id: record.id,
        body: search_data(record)
      )
    end

    def remove(record)
      client.delete(
        index: name,
        type: document_type(record),
        id: record.id
      )
    end

    def import(records)
      if records.first.respond_to?(:type)
        records.group_by { |item| item.type }.each_pair do |type, items|
          client_import items.select { |item| item.should_index? }
        end
      else
        client_import records
      end
    end

    def client_import(records)
      if records.any?
        client.bulk(
          index: name,
          type: document_type(records.first),
          body: records.map{|r| data = search_data(r); {index: {_id: data["_id"] || data["id"] || r.id, data: data}} }
        )
      end
    end

    def retrieve(record)
      client.get(
        index: name,
        type: document_type(record),
        id: record.id
      )["_source"]
    end

    def klass_document_type(klass)
      klass.model_name.to_s.underscore
    end

    protected

    def client
      Searchkick.client
    end

    def document_type(record)
      klass_document_type(record.class)
    end

    def search_data(record)
      source = record.search_data

      # stringify fields
      source = source.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo}

      # Mongoid 4 hack
      if defined?(BSON::ObjectId) and source["_id"].is_a?(BSON::ObjectId)
        source["_id"] = source["_id"].to_s
      end

      options = record.class.searchkick_options

      # conversions
      conversions_field = options[:conversions]
      if conversions_field and source[conversions_field]
        source[conversions_field] = source[conversions_field].map{|k, v| {query: k, count: v} }
      end

      # hack to prevent generator field doesn't exist error
      (options[:suggest] || []).map(&:to_s).each do |field|
        source[field] = nil if !source[field]
      end

      # locations
      (options[:locations] || []).map(&:to_s).each do |field|
        if source[field]
          if source[field].first.is_a?(Array) # array of arrays
            source[field] = source[field].map{|a| a.map(&:to_f).reverse }
          else
            source[field] = source[field].map(&:to_f).reverse
          end
        end
      end

      cast_big_decimal(source)

      # p search_data

      source.as_json
    end

    # change all BigDecimal values to floats due to
    # https://github.com/rails/rails/issues/6033
    # possible loss of precision :/
    def cast_big_decimal(obj)
      case obj
      when BigDecimal
        obj.to_f
      when Hash
        obj.each do |k, v|
          obj[k] = cast_big_decimal(v)
        end
      when Enumerable
        obj.map do |v|
          cast_big_decimal(v)
        end
      else
        obj
      end
    end

  end
end
