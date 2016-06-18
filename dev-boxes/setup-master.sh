#!/bin/bash

sudo apt-get install -y python-pip salt-master salt-minion python-gnupg

# copy the master / minion config from the repo
sudo cp /srv/hwhl/salt/states/saltstack/files/master /etc/salt/master
sudo cp /srv/hwhl/salt/states/saltstack/files/minion /etc/salt/minion
sudo sed -i "s/{{ pillar\['network'\]\['saltmaster'\] }}/127.0.0.1/g" /etc/salt/minion
sudo cp /srv/hwhl/salt/states/saltstack/files/autosign.conf /etc/salt/autosign.conf
sudo cp /srv/hwhl/salt/pillar/network/init.example.sls /srv/hwhl/salt/pillar/network/init.sls

sudo service salt-master restart; sudo service salt-minion restart
