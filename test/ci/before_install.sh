#!/usr/bin/env bash

set -e

gem install bundler

# https://docs.travis-ci.com/user/database-setup/#ElasticSearch
sudo apt-get purge elasticsearch
if [[ $ELASTICSEARCH_VERSION == 1* ]]; then
  curl -O https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION.deb
elif [[ $ELASTICSEARCH_VERSION == 2* ]]; then
  curl -O https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/deb/elasticsearch/$ELASTICSEARCH_VERSION/elasticsearch-$ELASTICSEARCH_VERSION.deb
else
  curl -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION.deb
fi
sudo dpkg -i --force-confnew elasticsearch-$ELASTICSEARCH_VERSION.deb
sudo service elasticsearch restart
sleep 10
