#!/bin/bash
#
# This script sets up the hosts as a control machine.
# Currently only supports Ubuntu. Might include more some day.
#
echo $OSTYPE
if [[ "$OSTYPE" == "linux-gnu"* ]];
then
    LINUX_TYPE=`egrep '^(NAME)=' /etc/os-release |sed -e 's/NAME=//g' -e 's/\"//g'`;
    echo $LINUX_TYPE
    if [[ "$LINUX_TYPE" == "Linux Mint" || "$LINUX_TYPE" == "Ubuntu" || "$LINUX_TYPE" == "Debian GNU/Linux" ]];
    then
        sudo apt-get install -y software-properties-common
        sudo apt-add-repository ppa:ansible/ansible --yes
        sudo apt-get update
        sudo apt-get install ansible python3-proxmoxer direnv -y

        # sh bin/workstation-ubuntu-init.sh
    fi

    if [[ "$LINUX_TYPE" == "Manjaro Linux" ]];
    then
      sudo pacman -Sy ansible direnv
      # sh bin/workstation-manjaro-init.sh
    fi
    if [[ "$LINUX_TYPE" == "Arch Linux" ]];
    then
      sudo pacman -Sy ansible direnv
      # sh bin/workstation-arch-init.sh
    fi


elif [[ "$OSTYPE" == "darwin"* ]]
then
    export PATH="$HOME/Library/Python/3.8/bin:/opt/homebrew/bin:$PATH"
    sudo pip3 install --upgrade pip
    pip3 install ansible
fi

# comment this out until there are requirements
# ansible-galaxy role install --force --roles-path galaxy/roles -r galaxy/requirements.yml
# ansible-galaxy collection install --force --collections-path ~/code/personal/ansible/collections -r $ansible_path/requirements.yml

ansible-galaxy collection install --force -r galaxy/requirements.yml
