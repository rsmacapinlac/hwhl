#!/bin/bash
# ============================================
# Generate SSH Keys for Homelab
# ============================================
# This script generates SSH key pairs for:
# 1. Terraform/Root access to LXC containers
# 2. Ansible user access
#
# Usage: ./bin/generate-ssh-keys.sh

set -euo pipefail

SSH_DIR="${HOME}/.ssh"
TERRAFORM_KEY_NAME="id_rsa_homelab_terraform"
ANSIBLE_KEY_NAME="id_rsa_homelab_ansible"

# Ensure .ssh directory exists
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# Function to generate SSH key pair
generate_key() {
    local key_name=$1
    local comment=$2
    local key_path="${SSH_DIR}/${key_name}"
    
    if [ -f "${key_path}" ]; then
        echo "⚠️  Key ${key_name} already exists. Skipping..."
        return
    fi
    
    echo "🔑 Generating ${key_name}..."
    ssh-keygen -t ed25519 -C "${comment}" -f "${key_path}" -N ""
    chmod 600 "${key_path}"
    chmod 644 "${key_path}.pub"
    echo "✅ Generated ${key_name} and ${key_name}.pub"
}

# Generate Terraform/Root key pair
echo "============================================"
echo "Generating Terraform/Root SSH Key Pair"
echo "============================================"
generate_key "${TERRAFORM_KEY_NAME}" "terraform-root@homelab"

# Generate Ansible user key pair
echo ""
echo "============================================"
echo "Generating Ansible User SSH Key Pair"
echo "============================================"
generate_key "${ANSIBLE_KEY_NAME}" "ansible@homelab"

# Display public keys
echo ""
echo "============================================"
echo "Public Keys Generated"
echo "============================================"
echo ""
echo "Terraform/Root public key:"
cat "${SSH_DIR}/${TERRAFORM_KEY_NAME}.pub"
echo ""
echo "Ansible user public key:"
cat "${SSH_DIR}/${ANSIBLE_KEY_NAME}.pub"
echo ""

# Instructions
echo "============================================"
echo "Next Steps"
echo "============================================"
echo ""
echo "1. Update Terraform configuration:"
echo "   Set ssh_public_key_file in terraform.tfvars or terraform.tfvars.j2:"
echo "   ssh_public_key_file = \"~/.ssh/${TERRAFORM_KEY_NAME}.pub\""
echo ""
echo "2. Update Ansible configuration:"
echo "   The ansible user key will be automatically used if you set:"
echo "   ANSIBLE_SSH_PRIVATE_KEY_FILE=~/.ssh/${ANSIBLE_KEY_NAME}"
echo ""
echo "   Or update ansible/roles/common/tasks/users.yml to reference:"
echo "   \"{{ lookup('env', 'HOME') }}/.ssh/${ANSIBLE_KEY_NAME}.pub\""
echo ""
echo "3. Add the Terraform private key to your SSH agent (optional):"
echo "   ssh-add ~/.ssh/${TERRAFORM_KEY_NAME}"
echo ""
echo "4. Add the Ansible private key to your SSH agent (optional):"
echo "   ssh-add ~/.ssh/${ANSIBLE_KEY_NAME}"
echo ""
