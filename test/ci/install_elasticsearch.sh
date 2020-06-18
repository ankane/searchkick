#!/usr/bin/env bash

set -e

CACHE_DIR=$HOME/elasticsearch/$ELASTICSEARCH_VERSION

if [ ! -d "$CACHE_DIR" ]; then
  if [[ $ELASTICSEARCH_VERSION == 7* ]]; then
    URL=https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION-linux-x86_64.tar.gz
  else
    URL=https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION.tar.gz
  fi

  wget -O elasticsearch-$ELASTICSEARCH_VERSION.tar.gz $URL
  tar xvfz elasticsearch-$ELASTICSEARCH_VERSION.tar.gz
  mv elasticsearch-$ELASTICSEARCH_VERSION $CACHE_DIR

  cd $CACHE_DIR

  bin/elasticsearch-plugin install analysis-kuromoji
  if [[ $ELASTICSEARCH_VERSION != 6.0.* ]]; then
    bin/elasticsearch-plugin install analysis-nori
  fi
  bin/elasticsearch-plugin install analysis-smartcn
  bin/elasticsearch-plugin install analysis-stempel
  bin/elasticsearch-plugin install analysis-ukrainian
else
  echo "Elasticsearch cached"
fi

cd $CACHE_DIR
bin/elasticsearch -d
for i in {1..12}; do wget -O- -v http://127.0.0.1:9200/ && break || sleep 5; done
