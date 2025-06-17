# Runbooks

This section provides step-by-step procedures for common operational tasks on our K3s infrastructure.

## 📚 Available Runbooks

### [🏗️ Cluster Operations](./cluster-operations.md)
- Adding new nodes to the cluster
- Upgrading K3s version
- Managing cluster certificates
- Cluster backup and restore procedures

### [🚀 Application Lifecycle](./application-lifecycle.md)
- Deploying new applications via GitOps
- Rolling updates and rollbacks
- Scaling applications
- Application troubleshooting

### [🚨 Incident Response](./incident-response.md)
- Emergency procedures for cluster outages
- Application failure response
- Network connectivity issues
- Storage and data recovery

### [💾 Backup and Restore](./backup-restore.md)
- Performing manual backups
- Automated backup verification
- Full cluster restoration
- Application data recovery

## 🔄 Quick Reference

### Emergency Contacts
- **Primary On-Call**: [Your contact info]
- **Secondary On-Call**: [Backup contact]
- **Infrastructure Team**: [Team contact]

### Critical Commands

```bash
# Check cluster health
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running

# Check ArgoCD status
kubectl get pods -n argocd
kubectl get applications -n argocd

# Check monitoring
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/grafana 3000:80

# Emergency cluster restart
sudo systemctl restart k3s
```

### Service URLs

| Service | URL | Access Method |
|---------|-----|---------------|
| ArgoCD | `https://localhost:8080` | `kubectl port-forward -n argocd svc/argocd-server 8080:443` |
| Grafana | `https://localhost:3000` | `kubectl port-forward -n monitoring svc/grafana 3000:80` |
| Prometheus | `https://localhost:9090` | `kubectl port-forward -n monitoring svc/prometheus-server 9090:80` |
| Longhorn | `https://localhost:8081` | `kubectl port-forward -n longhorn-system svc/longhorn-frontend 8081:80` |

## 📋 Runbook Template

When creating new runbooks, follow this template:

```markdown
# Runbook: [Task Name]

## Overview
Brief description of what this runbook covers.

## Prerequisites
- Required access levels
- Required tools
- Any dependencies

## Procedure

### Step 1: [Action]
```bash
# Commands with explanation
command --flag value
```

**Expected Result**: What should happen after this step.
**Troubleshooting**: What to do if it doesn't work.

### Step 2: [Next Action]
Continue with numbered steps...

## Verification
How to confirm the procedure was successful.

## Rollback
Steps to reverse the changes if needed.

## Notes
Any additional information or warnings.
```

---

*Each runbook provides detailed, step-by-step instructions for critical operational procedures. Always test procedures in development before applying to production.* 