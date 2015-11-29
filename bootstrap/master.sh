sudo add-apt-repository -y ppa:saltstack/salt
sudo apt-get update
sudo apt-get install -y python-pip salt-master salt-minion python-gnupg git-core

sudo rm /etc/salt/master
sudo wget -O - https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/configs/prod/master > /etc/salt/master

cd /srv
sudo git clone https://github.com/rsmacapinlac/hwhl hwhl-prod

sudo service salt-master restart; sudo service salt-minion restart
