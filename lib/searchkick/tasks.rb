require "rake"

namespace :searchkick do
  desc "re-index elasticsearch"
  task :reindex => :environment do
    klass = ENV["CLASS"].constantize
    klass.reindex
  end
end
