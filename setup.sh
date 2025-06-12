#!/bin/bash

# Set the playbook - default to main setup if none provided
if [ -z "$1" ]; then
  playbook="playbooks/setup.yaml"
  echo "No playbook specified, using default: $playbook"
else
  playbook=$1
  echo "Using specified playbook: $playbook"
fi

# Update package list and upgrade all packages
sudo apt update && sudo apt upgrade -y

# Install Ansible
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Run Ansible playbook
ansible-playbook ${playbook}
