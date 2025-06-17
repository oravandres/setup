# Infrastructure Documentation

This directory contains comprehensive documentation for our K3s-based infrastructure project that combines Ansible for initial provisioning and GitOps (ArgoCD) for continuous deployment.

## 📁 Documentation Structure

### [🏗️ Architecture](./architecture/)
High-level architecture overviews, component diagrams, and system design decisions.

- **K3s Cluster Design** - Control plane and worker node configuration
- **Component Architecture** - MetalLB, Ingress-NGINX, Longhorn, ArgoCD, Cert-manager, ExternalDNS
- **Network Architecture** - Load balancing, ingress, and DNS configuration
- **Storage Architecture** - Longhorn distributed storage setup

### [⚙️ Operations](./operations/)
Day-to-day operational procedures, monitoring, and maintenance guides.

- **Monitoring & Observability** - Prometheus, Grafana, and logging stack usage
- **Backup & Recovery** - Automated backup procedures and restore processes
- **Scaling Procedures** - Adding nodes and scaling applications
- **Troubleshooting Guides** - Common issues and resolution steps
- **Environment Management** - Managing dev, staging, and production environments

### [👨‍💻 Development](./development/)
Developer-focused documentation for working with the GitOps workflow.

- **GitOps Workflow** - How to deploy and manage applications
- **Application Onboarding** - Adding new applications to the platform
- **Secrets Management** - Working with Sealed Secrets
- **Local Development** - Setting up development environments

### [📚 Runbooks](./runbooks/)
Step-by-step operational procedures for common tasks.

- **Cluster Operations** - Node management, updates, and maintenance
- **Application Lifecycle** - Deployment, updates, and rollbacks
- **Incident Response** - Emergency procedures and recovery steps
- **Backup & Restore** - Detailed backup and recovery procedures

### [🔐 Security](./security/)
Security procedures, policies, and configuration guidelines.

- **Access Control** - RBAC and authentication setup
- **Certificate Management** - TLS certificate handling with Cert-manager
- **Secrets Management** - Sealed Secrets and secure credential handling
- **Security Policies** - Network policies and security configurations

## 🚀 Quick Start

For new team members:

1. Start with [Architecture Overview](./architecture/README.md) to understand the system design
2. Review [Development Workflow](./development/gitops-workflow.md) to understand how we deploy applications
3. Check [Operations Guide](./operations/README.md) for day-to-day procedures
4. Keep [Runbooks](./runbooks/) handy for step-by-step procedures

## 📖 Contributing to Documentation

- All documentation is written in Markdown
- Include diagrams where helpful using Mermaid syntax
- Keep documentation close to the code it describes
- Update documentation when making infrastructure changes
- Use clear, actionable language in runbooks

## 🔗 Related Resources

- [Main Project README](../README.md)
- [Ansible Infrastructure](../infrastructure/)
- [GitOps Configuration](../gitops/)
- [Setup Scripts](../scripts/)

---

*This documentation is maintained alongside the infrastructure code. Please keep it updated as the system evolves.* 