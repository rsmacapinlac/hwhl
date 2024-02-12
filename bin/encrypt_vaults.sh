#!/bin/bash
#
# This script will decrypt all known vaults to start development

ansible-vault encrypt roles/wg-easy/vars/main.yml
ansible-vault encrypt roles/pihole/vars/main.yml
ansible-vault encrypt roles/cloudflare-ddns/vars/main.yml
ansible-vault encrypt roles/traefik/vars/main.yml
ansible-vault encrypt roles/photoprism/vars/main.yml
ansible-vault encrypt roles/paperless-ng/vars/main.yml
ansible-vault encrypt roles/homepage/vars/main.yml
