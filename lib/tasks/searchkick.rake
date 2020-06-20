namespace :searchkick do
  desc "reindex model"
  task reindex: :environment do
    if ENV["CLASS"]
      klass = ENV["CLASS"].safe_constantize
      if klass
        klass.reindex
      else
        abort "Could not find class: #{ENV['CLASS']}"
      end
    else
      abort "USAGE: rake searchkick:reindex CLASS=Product"
    end
  end

  namespace :reindex do
    desc "reindex all models"
    task all: :environment do
      if Rails.respond_to?(:autoloaders) && Rails.autoloaders.zeitwerk_enabled?
        # fix for https://github.com/rails/rails/issues/37006
        Zeitwerk::Loader.eager_load_all
      else
        Rails.application.eager_load!
      end

      Searchkick.models.each do |model|
        puts "Reindexing #{model.name}..."
        model.reindex
      end
      puts "Reindex complete"
    end
  end
end
