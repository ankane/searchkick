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

    def store(model)
    end

    def remove(model)
    end

  end
end
