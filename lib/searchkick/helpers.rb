module Searchkick
  module Helpers

    def client
      Searchkick.client
    end

    def map_to_string(value)
      (value || []).map(&:to_s)
    end

    def location_value(value)
      if value.is_a?(Array)
        value.map(&:to_f).reverse
      elsif value.is_a?(Hash)
        {lat: value[:lat].to_f, lon: value[:lon].to_f}
      else
        value
      end
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
