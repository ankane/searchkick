require_relative "lib/searchkick/version"

Gem::Specification.new do |spec|
  spec.name          = "searchkick"
  spec.version       = Searchkick::VERSION
  spec.summary       = "Intelligent search made easy with Rails and Elasticsearch"
  spec.homepage      = "https://github.com/ankane/searchkick"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@chartkick.com"

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 2.4"

  spec.add_dependency "activemodel", ">= 5"
  spec.add_dependency "elasticsearch", ">= 6"
  spec.add_dependency "hashie"
  spec.add_dependency "faraday", "< 0.16"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rake"
end
