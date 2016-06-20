#!/bin/bash

sudo apt-get -y install salt-minion

# copy the minion configuration from the repo
sudo wget -O /etc/salt/minion https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/salt/states/saltstack/files/minion
# sudo cp /srv/hwhl/salt/states/saltstack/files/minion /etc/salt/minion
sudo sed -i "s/{{ pillar\['network'\]\['saltmaster'\] }}/$1/g" /etc/salt/minion
# sudo cat /etc/salt/minion

sudo service salt-minion restart
