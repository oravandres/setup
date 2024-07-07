#!/bin/bash

# Set the default environment if not provided
env=${1:-ubuntu}

# Update package list and upgrade all packages
sudo apt update && sudo apt upgrade -y

# Install common dependencies
sudo apt install -y software-properties-common curl git

# Install Ansible
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Run Ansible playbook
ansible-playbook playbooks/setup.yml -e env=${env}
