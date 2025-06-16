# Automated Development Environment Setup

Fully automated setup for a comprehensive development environment on a clean Linux installation using Ansible. This setup provides everything you need for modern development work, from essential system tools to specialized development environments and applications.

## 🚀 Features

### Base System
- Essential system packages (vim, git, net-tools, htop)

### Development Tools
- **Version Control**: Git with configuration
- **Programming Languages**: 
  - Python 3 and pip
  - Go programming language
  - Node.js and npm
- **Development Environments**: 
  - JetBrains Toolbox
  - Cursor AI-powered code editor
- **Infrastructure Tools**: 
  - Docker and Docker Compose
  - kubectl for Kubernetes management
- **AI Development Tools**: Specialized AI/ML development tools

### User Experience & Shell
- **Zsh Shell**: Complete Oh My Zsh setup with popular plugins
  - zsh-autosuggestions for command completion
  - zsh-syntax-highlighting for syntax coloring
  - zsh-bat for enhanced file viewing
  - Comprehensive plugin support (git, docker, kubectl, helm, npm, node, python, pip)
- **Enhanced File Tools**: bat/batcat for syntax-highlighted file viewing
- **Comprehensive Aliases**: 20+ useful command aliases for:
  - Directory navigation and file operations
  - Git workflow shortcuts
  - System monitoring and network tools
  - Python and Node.js development
  - Archive handling and text processing

### Desktop Applications (Optional)
- **Media & Graphics**: VLC Media Player, GIMP

### Database & Infrastructure (Specialized Playbooks)
- **PostgreSQL**: Database server setup
- **Redis**: In-memory data structure store
- **Apache Kafka**: Distributed event streaming platform

## 🛠 Installation

### Full Development Environment
Run the following command to download and execute the main setup:

```bash
curl -o- https://raw.githubusercontent.com/oravandres/setup/main/setup.sh | bash
```

This installs the core development environment including base tools, UX enhancements, and development tools.

## 🏗 Project Structure

```
setup/
├── playbooks/
│   ├── roles/
│   │   ├── base/          # Essential system packages & tools
│   │   ├── tools/         # Development tools & applications  
│   │   ├── ux/            # Shell environment & user experience
│   │   ├── media/         # Media applications (vlc, gimp)
│   │   ├── postgres/      # PostgreSQL database setup
│   │   ├── k3s/           # Kubernetes HA cluster setup
│   │   ├── redis/         # Redis in-memory store
│   │   └── kafka/         # Apache Kafka streaming platform
│   ├── setup.yaml         # Main playbook (base + ux + tools)
│   ├── setup_postgres.yaml
│   ├── setup_k3s.yaml
│   ├── setup_redis.yaml
│   └── setup_kafka.yaml
└── setup.sh              
```

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
