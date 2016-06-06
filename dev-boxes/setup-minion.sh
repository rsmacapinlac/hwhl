#!/bin/bash

sudo add-apt-repository -y ppa:saltstack/salt
sudo apt-get update
sudo apt-get install -y python-pip salt-minion python-gnupg

# copy the minion configuration from the repo
sudo cp /srv/hwhl/salt/states/saltstack/files/minion /etc/salt/minion
sudo sed -i "s/{{ pillar\['network'\]\['saltmaster'\] }}/$1/g" /etc/salt/minion
sudo cat /etc/salt/minion

sudo service salt-minion restart
