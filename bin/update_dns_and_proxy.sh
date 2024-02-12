#!/bin/bash

# eval `ssh-agent -s` && ssh-add ~/.ssh/id_rsa

# ansible-playbook playbooks/update_dns_and_proxy.yml -i inventory/core -u root -v
ansible-playbook update_dns_and_proxy.yml --tags debian
