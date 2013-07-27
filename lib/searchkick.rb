require "searchkick/version"
require "searchkick/reindex"
require "searchkick/search"
require "searchkick/model"
require "searchkick/tasks"
require "tire"

# TODO find better ActiveModel hook
ActiveModel::AttributeMethods::ClassMethods.send(:include, Searchkick::Model)
