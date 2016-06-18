#!/bin/bash

cd ~

sudo apt-get update && sudo apt-get upgrade && sudo apt-get install -y git-core

wget https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/bootstrap/setup-hostname.sh
wget https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/bootstrap/setup-salt.sh
wget https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/bootstrap/setup-master.sh

chmod +x setup-*

cd /srv; sudo git clone https://github.com/rsmacapinlac/hwhl hwhl

sudo ~/setup-hostname.sh makarov.infra.macapinlac.com
sudo ~/setup-salt.sh
sudo ~/setup-master.sh

