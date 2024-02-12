#!/bin/bash
#
# This script will decrypt all known vaults to start development

ansible-vault decrypt roles/wg-easy/vars/main.yml
ansible-vault decrypt roles/pihole/vars/main.yml
ansible-vault decrypt roles/cloudflare-ddns/vars/main.yml
ansible-vault decrypt roles/traefik/vars/main.yml
ansible-vault decrypt roles/photoprism/vars/main.yml
ansible-vault decrypt roles/paperless-ng/vars/main.yml
ansible-vault decrypt roles/homepage/vars/main.yml
