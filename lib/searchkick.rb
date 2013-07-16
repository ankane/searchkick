require "searchkick/version"
require "searchkick/reindex"
require "searchkick/search"
require "searchkick/model"
require "searchkick/tasks"
require "tire"
require "active_record" # TODO only require active_model

ActiveRecord::Base.send(:extend, Searchkick::Model)
