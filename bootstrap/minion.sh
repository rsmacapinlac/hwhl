#!/bin/sh

# get and install the saltstack
sudo add-apt-repository -y ppa:saltstack/salt
sudo apt-get update
sudo apt-get install -y git-core python-pip salt-minion python-gnupg

sudo wget -O /etc/salt/minion https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/configs/shared/minion
sudo sh -c 'echo shino.db.macapinlac.com > /etc/hostname'; sudo hostname shino.db.macapinlac.com

sudo service salt-minion restart
