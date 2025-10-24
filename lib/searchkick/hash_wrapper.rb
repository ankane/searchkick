module Searchkick
  class HashWrapper
    def initialize(attributes)
      @attributes = attributes
    end

    def [](name)
      @attributes[name.to_s]
    end

    def to_h
      @attributes
    end

    def to_json
      @attributes.to_json
    end

    def method_missing(name, ...)
      if @attributes.key?(name.to_s)
        self[name]
      else
        super
      end
    end

    def respond_to_missing?(name, ...)
      @attributes.key?(name.to_s) || super
    end

    def inspect
      attributes = @attributes.reject { |k, v| k[0] == "_" }.map { |k, v| "#{k}: #{v.inspect}" }
      attributes.unshift(attributes.pop) # move id to start
      "#<#{self.class.name} #{attributes.join(", ")}>"
    end
  end
end
