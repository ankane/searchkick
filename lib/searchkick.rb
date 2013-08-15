require "tire"
require "searchkick/version"
require "searchkick/reindex"
require "searchkick/results"
require "searchkick/search"
require "searchkick/similar"
require "searchkick/model"
require "searchkick/tasks"
require "searchkick/logger" if defined?(Rails)

module Searchkick

  def self.reindex_all
    (Searchkick::Reindex.instance_variable_get(:@descendents) || []).each do |model|
      model.reindex
    end
    true
  end

end

# TODO find better ActiveModel hook
ActiveModel::AttributeMethods::ClassMethods.send(:include, Searchkick::Model)
ActiveRecord::Base.send(:extend, Searchkick::Model) if defined?(ActiveRecord)
