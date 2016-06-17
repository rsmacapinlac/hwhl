#!/bin/sh

sudo sh -c 'echo makarov.infra.macapinlac.com > /etc/hostname'; sudo hostname makarov.infra.macapinlac.com

# get and install the saltstack
sudo add-apt-repository -y ppa:saltstack/salt
sudo apt-get update
sudo apt-get install -y git-core python-pip salt-master salt-minion python-gnupg

cd /srv; sudo git clone https://github.com/rsmacapinlac/hwhl hwhl

sudo cp /srv/hwhl/salt/states/saltstack/files/master /etc/salt/master
sudo cp /srv/hwhl/salt/states/saltstack/files/minion /etc/salt/minion
sudo cp /srv/hwhl/salt/states/saltstack/files/autosign.conf /etc/salt/autosign.conf

# sudo wget -O /etc/salt/master https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/configs/bootstrap/master
# sudo wget -O /etc/salt/autosign.conf https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/configs/bootstrap/autosign.conf

sudo service salt-master restart; sudo service salt-minion restart
