require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

File.delete("elasticsearch.log") if File.exists?("elasticsearch.log")
Tire.configure { logger "elasticsearch.log", :level => "debug" }
