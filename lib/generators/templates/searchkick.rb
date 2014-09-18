Searchkick.configure do |config|

  # Background processor for :reindex_async
  # Make sure whatever background processor you choose, it is setup
  # and working as expected.
  # Default is :delayed_job. Other valid options are :resque  
  # config.background_proccessor = :delayed_job

  # Path of elastic search
  # By default it takes value from of ELASTICSEARCH_URL from env
  # config.elasticsearch_url = ENV["ELASTICSEARCH_URL"]

end
