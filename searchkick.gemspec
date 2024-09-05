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

  spec.required_ruby_version = ">= 3.1"

  spec.add_dependency "activemodel", ">= 6.1"
  spec.add_dependency "hashie"
end
