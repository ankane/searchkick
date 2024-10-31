module Searchkick
  class Script
    attr_reader :source, :lang, :params

    def initialize(source, lang: "painless", params: {})
      @source = source
      @lang = lang
      @params = params
    end

    def to_h
      {
        source:,
        lang:,
        params:
      }
    end
  end
end
