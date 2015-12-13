#!/bin/sh

# get and install the saltstack
sudo add-apt-repository -y ppa:saltstack/salt
sudo apt-get update
sudo apt-get install -y git-core python-pip salt-master salt-minion python-gnupg

sudo wget -O /etc/salt/master https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/configs/bootstrap/master
sudo wget -O /etc/salt/autosign.conf https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/configs/bootstrap/autosign.conf

cd /srv; sudo git clone https://github.com/rsmacapinlac/hwhl hwhl

sudo service salt-master restart; sudo service salt-minion restart
