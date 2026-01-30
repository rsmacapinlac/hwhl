#!/bin/bash
# Wrapper to run terraform from repository root
# Usage: ./bin/terraform.sh [terraform options]
cd "$(dirname "$0")/../terraform" || exit 1
terraform "$@" -var-file=../homelab_config/terraform.tfvars
