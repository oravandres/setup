# Automated Setup

Fully automated setup for a working environment on a clean Linux installation using Ansible.

## Features

- Installs essential base packages (git, vim, net-tools)
- Installs and configures Zsh and Oh My Zsh
- Installs Node Version Manager (NVM) and latest Node.js versions
- Installs Go Version Manager (GVM) and latest Go versions

## Requirements

- sudo privileges

## Installation

Run the following command to download and execute the setup script:

```bash
curl -o- https://raw.githubusercontent.com/oravandres/setup/main/setup/setup.sh | bash
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
