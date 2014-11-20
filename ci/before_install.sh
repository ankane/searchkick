#!/usr/bin/env bash

wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.3.2.deb
sudo dpkg -i elasticsearch-1.3.2.deb
sudo service elasticsearch restart

if [ -n "$NOBRAINER" ]; then
  source /etc/lsb-release && echo "deb http://download.rethinkdb.com/apt $DISTRIB_CODENAME main" | sudo tee /etc/apt/sources.list.d/rethinkdb.list
  wget -qO- http://download.rethinkdb.com/apt/pubkey.gpg | sudo apt-key add -
  sudo apt-get update -q
  sudo apt-get install rethinkdb
  sudo cp /etc/rethinkdb/default.conf.sample /etc/rethinkdb/instances.d/instance1.conf
  sudo service rethinkdb restart
fi
