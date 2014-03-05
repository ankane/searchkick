require "elasticsearch/model"
require "searchkick/version"
require "searchkick/index"
require "searchkick/reindex"
require "searchkick/results"
require "searchkick/query"
require "searchkick/search"
require "searchkick/similar"
require "searchkick/model"
require "searchkick/tasks"
# TODO add logger
# require "searchkick/logger" if defined?(Rails)

module Searchkick

  def self.client
    @client ||= Elasticsearch::Client.new
  end

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

require "active_record" # TODO remove

# TODO find better ActiveModel hook
ActiveModel::Callbacks.send(:include, Searchkick::Model) if defined?(ActiveModel)
ActiveRecord::Base.send(:extend, Searchkick::Model) if defined?(ActiveRecord)
