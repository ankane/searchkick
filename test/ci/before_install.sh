#!/usr/bin/env bash

gem install bundler

sudo apt-get purge elasticsearch
if [[ $ELASTICSEARCH_VERSION == 1* ]]; then
  wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION.deb
else
  wget https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/deb/elasticsearch/$ELASTICSEARCH_VERSION/elasticsearch-$ELASTICSEARCH_VERSION.deb
fi
sudo dpkg -i elasticsearch-$ELASTICSEARCH_VERSION.deb
sudo service elasticsearch start

if [ -n "$NOBRAINER" ]; then
  source /etc/lsb-release && echo "deb http://download.rethinkdb.com/apt $DISTRIB_CODENAME main" | sudo tee /etc/apt/sources.list.d/rethinkdb.list
  wget -qO- http://download.rethinkdb.com/apt/pubkey.gpg | sudo apt-key add -
  sudo apt-get update -q
  sudo apt-get install rethinkdb
  sudo cp /etc/rethinkdb/default.conf.sample /etc/rethinkdb/instances.d/instance1.conf
  sudo service rethinkdb restart
fi
