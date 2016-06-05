#!/bin/bash

sudo add-apt-repository -y ppa:saltstack/salt
sudo apt-get update
sudo apt-get install -y python-pip salt-minion python-gnupg
sudo cp /vagrant/configs/minion /etc/salt/minion
sudo service salt-minion restart
