#!/bin/bash

VERSION=`lsb_release -rs`
CODENAME=`lsb_release -cs`

sudo wget -o - https://repo.saltstack.com/apt/ubuntu/$VERSION/amd64/latest/saltstack-gpg-key.pub | sudo apt-key add -
sudo echo "deb http://repo.saltstack.com/apt/ubuntu/$VERSION/amd64/latest $CODENAME main" > /etc/apt/sources.list.d/saltstack.list:
sudo apt-get update
# sudo apt-get install -y python-pip salt-master salt-minion python-gnupg
