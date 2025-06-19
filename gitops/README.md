# GitOps Infrastructure

**Declarative, Git-driven infrastructure and application management for K3s homelab.**

## 🎯 Overview

This GitOps implementation uses **ArgoCD** to manage both infrastructure components and applications through declarative configurations stored in Git. Every change goes through Git, ensuring auditability, repeatability, and automated deployment.

## 📁 Directory Structure

```
gitops/
├── argocd/                    # ArgoCD ApplicationSets
│   ├── infrastructure-appset.yaml   # Platform components
│   └── applications-appset.yaml     # User applications
├── applications/              # Application manifests
│   └── example-app/          # Sample application
├── environments/             # Environment-specific configurations
│   ├── dev/                 # Development environment
│   │   └── values.yaml      # Dev-specific values
│   └── production/          # Production environment
│       └── values.yaml      # Production-specific values
├── infrastructure/          # Platform component charts
│   ├── Chart.yaml          # Helm chart definition
│   ├── values.yaml         # Default values
│   └── charts/             # Dependencies (auto-generated)
└── secrets/                # Sealed secrets by environment
    ├── dev/               # Development secrets
    └── production/        # Production secrets
```

## 🚀 Quick Start

### 1. Deploy ArgoCD ApplicationSets

```bash
# Apply infrastructure ApplicationSet
kubectl apply -f gitops/argocd/infrastructure-appset.yaml

# Apply applications ApplicationSet
kubectl apply -f gitops/argocd/applications-appset.yaml

# Verify deployment
kubectl get applications -n argocd
kubectl get applicationsets -n argocd
```

### 2. Access ArgoCD UI

```bash
# Port-forward to ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d

# Access UI: https://localhost:8080
# Username: admin
# Password: <decoded-password>
```

### 3. Monitor Sync Status

```bash
# Check application status
kubectl get applications -n argocd -o wide

# Get detailed application info
kubectl describe application k3s-production-infrastructure-core -n argocd

# Force manual sync
kubectl patch application k3s-production-infrastructure-core -n argocd \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' \
  --type=merge
```

## 🏗️ Infrastructure Management

### ApplicationSet Configuration

The infrastructure is deployed using ArgoCD ApplicationSets that automatically generate applications for each environment:

```yaml
# gitops/argocd/infrastructure-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: infrastructure-core
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: k3s-dev-local
        environment: dev
        values_file: gitops/environments/dev/values.yaml
      - cluster: k3s-production  
        environment: production
        values_file: gitops/environments/production/values.yaml
```

### Infrastructure Components

The platform includes these core components managed via GitOps:

| Component | Purpose | Namespace | Status |
|-----------|---------|-----------|--------|
| **cert-manager** | TLS certificate automation | cert-manager | ✅ |
| **metallb** | LoadBalancer services | metallb-system | ✅ |
| **ingress-nginx** | HTTP/HTTPS ingress | ingress-nginx | ✅ |
| **longhorn** | Distributed storage | longhorn-system | ✅ |
| **sealed-secrets** | GitOps-safe secrets | kube-system | ✅ |
| **external-dns** | DNS automation | external-dns | 🔄 |

### Environment-Specific Values

Each environment has its own configuration file:

**Development (`environments/dev/values.yaml`):**
```yaml
global:
  environment: dev
  domain: "dev.localhost"
  cluster_name: "k3s-dev-local"

# Minimal resources for localhost development
metallb:
  enabled: false  # Use NodePort services

longhorn:
  enabled: false  # Use local storage

monitoring:
  retention: "3d"  # Short retention
```

**Production (`environments/production/values.yaml`):**
```yaml
global:
  environment: production
  domain: "cluster.local" 
  cluster_name: "k3s-production"

# Full production configuration
metallb:
  enabled: true
  ip_pool:
    addresses:
    - "10.0.0.30-10.0.0.50"

longhorn:
  enabled: true
  replicas: 3

monitoring:
  retention: "30d"  # Full retention
```

## 📱 Application Deployment

### Adding New Applications

1. **Create application directory:**
```bash
mkdir -p gitops/applications/my-app/{base,environments/dev,environments/production}
```

2. **Create Helm chart structure:**
```bash
# gitops/applications/my-app/base/Chart.yaml
apiVersion: v2
name: my-app
description: My awesome application
type: application
version: 0.1.0
appVersion: "1.0.0"
```

3. **Define application manifests:**
```yaml
# gitops/applications/my-app/base/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-app.fullname" . }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "my-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "my-app.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
```

4. **Configure environment-specific values:**
```yaml
# gitops/applications/my-app/environments/production/values.yaml
replicaCount: 3

image:
  repository: my-app
  tag: "v1.0.0"

ingress:
  enabled: true
  hosts:
  - host: my-app.cluster.local
    paths:
    - path: /
      pathType: Prefix
```

5. **Commit and push:**
```bash
git add gitops/applications/my-app/
git commit -m "feat: add my-app application"
git push origin main
```

6. **ArgoCD will automatically detect and deploy the application!**

### Application Lifecycle Management

**Check application status:**
```bash
# List all applications
kubectl get applications -n argocd

# Get application details
kubectl describe application my-app-production -n argocd

# View application in ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Manual sync operations:**
```bash
# Sync specific application
kubectl patch application my-app-production -n argocd \
  -p '{"operation":{"sync":{"revision":"HEAD"}}}' --type=merge

# Refresh application (pull latest Git state)
kubectl patch application my-app-production -n argocd \
  -p '{"operation":{"initiatedBy":{"username":"admin"}}}' --type=merge
```

**Rollback operations:**
```bash
# Rollback to previous version
kubectl patch application my-app-production -n argocd \
  -p '{"operation":{"sync":{"revision":"<previous-commit-hash>"}}}' --type=merge
```

## 🔐 Secret Management

### Sealed Secrets Workflow

1. **Create regular Kubernetes secret:**
```bash
kubectl create secret generic my-app-secret \
  --from-literal=database-password=supersecret \
  --from-literal=api-key=abc123 \
  --dry-run=client -o yaml > temp-secret.yaml
```

2. **Seal the secret:**
```bash
kubeseal -f temp-secret.yaml -w my-app-sealed-secret.yaml
rm temp-secret.yaml  # Remove plaintext secret
```

3. **Commit sealed secret to Git:**
```bash
git add my-app-sealed-secret.yaml
git commit -m "feat: add sealed secret for my-app"
git push origin main
```

4. **ArgoCD deploys the sealed secret automatically**

### Secret Management Commands

```bash
# Install kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Get sealing certificate
kubeseal --fetch-cert > public.pem

# Seal secret with specific certificate
kubeseal --cert=public.pem -f secret.yaml -w sealed-secret.yaml

# Verify sealed secret
kubectl get sealedsecrets -A
kubectl get secrets -A | grep my-app
```

## 🔄 GitOps Workflows

### Development Workflow

1. **Feature development:**
```bash
# Create feature branch
git checkout -b feature/my-new-feature

# Make changes to application manifests
vim gitops/applications/my-app/base/values.yaml

# Commit changes
git add .
git commit -m "feat: update my-app configuration"
git push origin feature/my-new-feature
```

2. **Testing in development:**
```bash
# Deploy to dev environment by merging to main
git checkout main
git merge feature/my-new-feature
git push origin main

# ArgoCD automatically syncs dev environment
```

3. **Production promotion:**
```bash
# Update production values if needed
vim gitops/applications/my-app/environments/production/values.yaml

# Commit production changes
git add .
git commit -m "feat: promote my-app to production"
git push origin main

# ArgoCD syncs production (manual approval if configured)
```

### Hotfix Workflow

```bash
# Create hotfix branch from main
git checkout -b hotfix/critical-fix

# Apply critical fix
vim gitops/applications/my-app/base/templates/deployment.yaml

# Commit and push
git add .
git commit -m "fix: critical security patch"
git push origin hotfix/critical-fix

# Merge to main for immediate deployment
git checkout main
git merge hotfix/critical-fix
git push origin main
```

## 📊 Monitoring GitOps

### ArgoCD Metrics

ArgoCD exposes Prometheus metrics for monitoring:

```bash
# Check ArgoCD metrics
kubectl port-forward svc/argocd-metrics -n argocd 8082:8082
curl http://localhost:8082/metrics
```

**Key metrics to monitor:**
- `argocd_app_info` - Application information
- `argocd_app_health_status` - Application health status  
- `argocd_app_sync_total` - Number of sync operations
- `argocd_cluster_connection_status` - Cluster connectivity

### Application Health Checks

```bash
# Check application health
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.health.status}{"\t"}{.status.sync.status}{"\n"}{end}'

# Get applications with issues
kubectl get applications -n argocd -o json | \
  jq -r '.items[] | select(.status.health.status != "Healthy" or .status.sync.status != "Synced") | .metadata.name'
```

### Sync Status Monitoring

```bash
# Monitor sync events
kubectl get events -n argocd --field-selector involvedObject.kind=Application

# Check sync history
kubectl describe application my-app-production -n argocd | grep -A 10 "Operation:"
```

## 🛠️ Troubleshooting

### Common Issues

**Application stuck in "Progressing" state:**
```bash
# Check application events
kubectl describe application my-app-production -n argocd

# Check resource status
kubectl get pods,svc,ingress -n my-app-namespace

# Force refresh and sync
kubectl patch application my-app-production -n argocd \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' \
  --type=merge
```

**"OutOfSync" status:**
```bash
# Compare desired vs actual state
kubectl get application my-app-production -n argocd -o yaml

# Check for manual changes to resources
kubectl diff -f gitops/applications/my-app/

# Sync to restore desired state
kubectl patch application my-app-production -n argocd \
  -p '{"operation":{"sync":{"revision":"HEAD","prune":true}}}' \
  --type=merge
```

**Sealed secret not decrypting:**
```bash
# Check sealed-secrets controller
kubectl get pods -n kube-system | grep sealed-secrets

# Verify sealed secret syntax
kubeseal --validate -f my-sealed-secret.yaml

# Check controller logs
kubectl logs -n kube-system deployment/sealed-secrets-controller
```

### Recovery Procedures

**Reset ArgoCD application:**
```bash
# Delete application (keeps resources)
kubectl delete application my-app-production -n argocd

# Recreate from ApplicationSet
kubectl apply -f gitops/argocd/applications-appset.yaml
```

**Emergency rollback:**
```bash
# Rollback via Git
git revert <problematic-commit>
git push origin main

# Or rollback specific application
kubectl patch application my-app-production -n argocd \
  -p '{"operation":{"sync":{"revision":"<good-commit-hash>"}}}' \
  --type=merge
```

## 🔧 Advanced Configuration

### Custom Health Checks

```yaml
# Custom health check for applications
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.health.my-app_v1_MyResource: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.phase == "Running" then
        hs.status = "Healthy"
        hs.message = "Resource is running"
      else
        hs.status = "Progressing"
        hs.message = "Resource is starting"
      end
    end
    return hs
```

### Sync Policies

```yaml
# Automatic sync with self-healing
spec:
  syncPolicy:
    automated:
      prune: true        # Remove resources not in Git
      selfHeal: true     # Correct drift automatically
      allowEmpty: false  # Don't sync empty applications
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Multi-Cluster Setup

```yaml
# Register additional clusters
apiVersion: v1
kind: Secret
metadata:
  name: staging-cluster-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: staging-cluster
  server: https://staging-cluster-api.example.com
  config: |
    {
      "bearerToken": "<bearer-token>",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<base64-ca-cert>"
      }
    }
```

## 📚 Best Practices

### Repository Structure
- **Separate infrastructure and applications** into different directories
- **Use environment-specific value files** for configuration
- **Keep secrets encrypted** with Sealed Secrets
- **Tag releases** for production deployments

### Deployment Strategy
- **Test in development** before production
- **Use progressive delivery** for critical applications
- **Monitor application health** during deployments
- **Have rollback procedures** ready

### Security
- **Limit ArgoCD permissions** with RBAC
- **Use least-privilege** service accounts
- **Encrypt secrets** before committing to Git
- **Audit Git access** and changes

## 📖 Related Documentation

- **[Architecture Overview](../docs/architecture/README.md)** - System design and components
- **[Operations Guide](../docs/operations/README.md)** - Day-to-day operational procedures
- **[Secret Management](secrets/README.md)** - Detailed sealed secrets documentation

---

**GitOps provides a reliable, auditable way to manage infrastructure and applications. Every change is tracked, tested, and deployed consistently across environments.** 