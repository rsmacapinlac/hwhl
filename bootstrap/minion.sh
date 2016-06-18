#!/bin/bash

sudo apt-get install -y --allow-unauthenticated python-pip salt-minion
python-gnupg

sudo wget -O /etc/salt/minion https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/salt/states/saltstack/files/minion

# copy the minion configuration from the repo
# sudo cp /srv/hwhl/salt/states/saltstack/files/minion /etc/salt/minion
sudo sed -i "s/{{ pillar\['network'\]\['saltmaster'\] }}/$1/g" /etc/salt/minion
# sudo cat /etc/salt/minion

sudo service salt-minion restart
