#!/bin/sh

# get and install the saltstack
sudo add-apt-repository -y ppa:saltstack/salt
sudo apt-get update
sudo apt-get install -y git-core python-pip salt-master salt-minion python-gnupg git-core

sudo wget -O /etc/salt/master https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/configs/shared/master

cd /srv
sudo git clone https://github.com/rsmacapinlac/hwhl salt

sudo service salt-master restart; sudo service salt-minion restart
