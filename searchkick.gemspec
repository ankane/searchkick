require_relative "lib/searchkick/version"

Gem::Specification.new do |spec|
  spec.name          = "searchkick"
  spec.version       = Searchkick::VERSION
  spec.summary       = "Intelligent search made easy with Rails and Elasticsearch or OpenSearch"
  spec.homepage      = "https://github.com/ankane/searchkick"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@ankane.org"

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 2.4"

  spec.add_dependency "activemodel", ">= 5"
  spec.add_dependency "elasticsearch", ">= 6", "< 7.14"
  spec.add_dependency "hashie"
end
