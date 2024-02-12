#!/bin/bash

# eval `ssh-agent -s` && ssh-add ~/.ssh/id_rsa

ansible-playbook --vault-pass-file .vault-pass-file --tags debian dns.yml -i inventory/proxmox.yml
ansible-playbook --vault-pass-file .vault-pass-file --tags debian proxy.yml -i inventory/proxmox.yml
