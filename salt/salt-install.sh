#!/bin/bash

#sudo wget -O /etc/apt/sources.list https://gist.githubusercontent.com/sawasy/cdf4049cfb4d0615c48c/raw/a26b38898f101ad406df07c618339c1744f4a8af/sources.list
sudo add-apt-repository -y ppa:saltstack/salt
sudo apt-get update
sudo apt-get install -y salt-minion

sudo mkdir /srv/centrex
sudo chown mls: /srv/centrex
git clone  git@bitbucket.org:ethicalrain/centrex.git /srv/centrex

sudo ln -s /srv/centrex/salt /srv/salt
sudo ln -s /srv/centrex/salt/pillar /srv/pillar

sudo cp /srv/salt/configs/minion /etc/salt/minion
sudo service salt-minion restart

