require "tire"
require "searchkick/version"
require "searchkick/reindex"
require "searchkick/results"
require "searchkick/search"
require "searchkick/similar"
require "searchkick/model"
require "searchkick/tasks"
require "searchkick/logger" if defined?(Rails)

# TODO find better ActiveModel hook
ActiveModel::AttributeMethods::ClassMethods.send(:include, Searchkick::Model)
ActiveRecord::Base.send(:extend, Searchkick::Model) if defined?(ActiveRecord)
