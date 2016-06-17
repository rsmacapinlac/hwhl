#!/bin/sh

# setup the hostname from the first param
sudo sh -c 'echo $1 > /etc/hostname'; sudo hostname $1

# get and install the saltstack
sudo add-apt-repository -y ppa:saltstack/salt
sudo apt-get update
sudo apt-get install -y python-pip salt-minion python-gnupg

# /srv/hwhl/salt/states/saltstack/files/minion /etc/salt/minion
sudo wget -O /etc/salt/minion https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/salt/states/saltstack/files/minion
sudo sed -i "s/{{ pillar\['network'\]\['saltmaster'\] }}/$2/g" /etc/salt/minion

sudo service salt-minion restart
