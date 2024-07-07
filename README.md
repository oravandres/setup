# Automated Setup

Fully automated setup for a working environment on a clean Linux installation using Ansible.

## Features

- Installs essential base packages (git, vim, net-tools)
- Installs and configures Zsh and Oh My Zsh
- Installs Node Version Manager (NVM) and latest Node.js versions
- Installs Go Version Manager (GVM) and latest Go versions

## Requirements
- 
- sudo privileges

## Installation

1. Clone the repository:

    ```bash
    git clone git@github.com:oravandres/setup.git auto-setup
    cd ./auto-setup
    ```

2. Make the setup script executable:

    ```bash
    chmod +x setup.sh
    ```

3. Run the setup script (default environment is `ubuntu`):

    ```bash
    ./setup.sh
    ```

   Or specify a different environment:

    ```bash
    ./setup.sh raspberry-pi-4b-8gb
    ```
