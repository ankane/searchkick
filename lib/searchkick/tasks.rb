require "rake"

namespace :searchkick do
  desc "re-index elasticsearch"
  namespace :reindex do
    desc "reindex a Model by passing it as an argument"
    task :class, [:klass] => [:environment] do |t, args|
      begin
        args[:klass].constantize.reindex
      rescue
        puts "#{args[:klass]} model not found"
      end
    end

    desc "reindex all models"
    task :all => [:environment] do
      Dir[Rails.root + "app/models/**/*.rb"].each { |path| require path }
      models = ActiveRecord::Base.descendants.map(&:name)
      models.each do |model|
        model.constantize.reindex if model.respond_to?(:search)
      end
    end
  end
end
