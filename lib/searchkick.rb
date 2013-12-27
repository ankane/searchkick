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
  @callbacks = true

  def self.enable_callbacks
    @callbacks = true
  end

  def self.disable_callbacks
    @callbacks = false
  end

  def self.callbacks?
    @callbacks
  end
end

# TODO find better ActiveModel hook
ActiveModel::Callbacks.send(:include, Searchkick::Model)
ActiveRecord::Base.send(:extend, Searchkick::Model) if defined?(ActiveRecord)
