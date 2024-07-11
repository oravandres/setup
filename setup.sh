#!/bin/bash

# Ensure a playbook is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <playbook>"
  exit 1
fi

# Set the playbook
playbook=$1

# Update package list and upgrade all packages
sudo apt update && sudo apt upgrade -y

# Install Ansible
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Run Ansible playbook
ansible-playbook ${playbook}
