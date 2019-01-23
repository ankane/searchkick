#!/usr/bin/env bash

set -e

CACHE_DIR=$HOME/elasticsearch/$ELASTICSEARCH_VERSION

if [ ! -d "$CACHE_DIR" ]; then
  if [[ $ELASTICSEARCH_VERSION == 1* ]]; then
    URL=https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION.tar.gz
  elif [[ $ELASTICSEARCH_VERSION == 2* ]]; then
    URL=https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/tar/elasticsearch/$ELASTICSEARCH_VERSION/elasticsearch-$ELASTICSEARCH_VERSION.tar.gz
  else
    URL=https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION.tar.gz
  fi

  wget $URL
  tar xvfz elasticsearch-$ELASTICSEARCH_VERSION.tar.gz
  mv elasticsearch-$ELASTICSEARCH_VERSION $CACHE_DIR
else
  echo "Elasticsearch cached"
fi

cd $CACHE_DIR
bin/elasticsearch -d
for i in {1..12}; do wget -O- -v http://127.0.0.1:9200/ && break || sleep 5; done
