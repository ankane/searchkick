require "rake"

namespace :searchkick do

  desc "reindex model"
  task :reindex => :environment do
    if ENV["CLASS"]
      klass = ENV["CLASS"].constantize rescue nil
      if klass
        klass.reindex
      else
        abort "Could not find class: #{ENV["CLASS"]}"
      end
    else
      abort "USAGE: rake searchkick:reindex CLASS=Product"
    end
  end

  if defined?(Rails)

    namespace :reindex do
      desc "reindex all models"
      task :all => :environment do
        dir = ENV['DIR'].to_s != '' ? ENV['DIR'] : Rails.root.join("app/models")
        puts "Loading models from: #{dir}"
        Rails.application.eager_load!
        (Searchkick::Reindex.instance_variable_get(:@descendents) || []).each do |model|
          puts "Reindexing #{model.name.try(:pluralize)} ..."
          model.reindex
        end
        puts "Reindexing Done."
      end
    end

  end

end
