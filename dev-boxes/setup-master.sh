#!/bin/bash

sudo add-apt-repository -y ppa:saltstack/salt
sudo apt-get update
sudo apt-get install -y python-pip salt-master salt-minion python-gnupg

sudo cp /vagrant/configs/master /etc/salt/master
sudo cp /vagrant/configs/minion /etc/salt/minion

sudo cp /vagrant/configs/autosign.conf /etc/salt/autosign.conf
sudo service salt-master restart; sudo service salt-minion restart
