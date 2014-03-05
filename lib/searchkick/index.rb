module Searchkick
  class Index
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def create(options = {})
      Searchkick.client.indices.create index: name, body: options
    end

    def delete
      Searchkick.client.indices.delete index: name
    end

    def exists?
      Searchkick.client.indices.exists index: name
    end

    def refresh
      Searchkick.client.indices.refresh index: name
    end

    def store(record)
      Searchkick.client.index(
        index: name,
        type: record.document_type,
        id: record.id,
        body: record.as_indexed_json
      )
    end

    def remove(record)
      Searchkick.client.delete(
        index: name,
        type: record.document_type,
        id: record.id
      )
    end

    def import(records)
      if records.any?
        Searchkick.client.bulk(
          index: name,
          type: records.first.document_type,
          body: records.map{|r| {index: {_id: r.id, data: r.as_indexed_json}} }
        )
      end
    end

  end
end
