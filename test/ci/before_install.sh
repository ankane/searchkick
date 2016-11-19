#!/usr/bin/env bash

set -e

gem install bundler

if [[ $ELASTICSEARCH_VERSION == 1* ]]; then
  curl -L -O https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION.tar.gz
elif [[ $ELASTICSEARCH_VERSION == 2* ]]; then
  curl -L -O https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/tar/elasticsearch/$ELASTICSEARCH_VERSION/elasticsearch-$ELASTICSEARCH_VERSION.tar.gz
else
  curl -L -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION.tar.gz
fi
tar -xvf elasticsearch-$ELASTICSEARCH_VERSION.tar.gz
cd elasticsearch-$ELASTICSEARCH_VERSION/bin
./elasticsearch -d
wget -O- --waitretry=1 --tries=30 --retry-connrefused -v http://127.0.0.1:9200/
