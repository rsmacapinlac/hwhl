#!/bin/bash
# Wrapper to run ansible-playbook from repository root
# Usage: ./bin/ansible-playbook.sh [ansible-playbook options]
cd "$(dirname "$0")/../ansible" || exit 1
ansible-playbook "$@"
