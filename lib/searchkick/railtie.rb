module Searckick
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/searchkick.rake"
    end
  end
end
