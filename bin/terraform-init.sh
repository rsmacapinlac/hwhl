#!/bin/bash
#
# This script installs Terraform on the control machine.
# Supports Ubuntu/Debian, Arch/Manjaro, and macOS.
#
echo $OSTYPE

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    LINUX_TYPE=$(egrep '^(NAME)=' /etc/os-release | sed -e 's/NAME=//g' -e 's/"//g')
    echo $LINUX_TYPE

    if [[ "$LINUX_TYPE" == "Linux Mint" || "$LINUX_TYPE" == "Ubuntu" || "$LINUX_TYPE" == "Debian GNU/Linux" ]]; then
        # Install HashiCorp GPG key and repo
        sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
        wget -O- https://apt.releases.hashicorp.com/gpg | \
            gpg --dearmor | \
            sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
            https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
            sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt-get update
        sudo apt-get install -y terraform
    fi

    if [[ "$LINUX_TYPE" == "Manjaro Linux" || "$LINUX_TYPE" == "Arch Linux" ]]; then
        sudo pacman -Sy terraform
    fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS via Homebrew
    brew tap hashicorp/tap
    brew install hashicorp/tap/terraform
fi

# Verify installation
terraform --version
