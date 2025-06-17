# Development Guide

This guide explains how developers work with our K3s infrastructure using GitOps principles and ArgoCD for continuous deployment.

## 🔄 GitOps Workflow Overview

Our development workflow follows GitOps principles, where Git is the single source of truth for both infrastructure and application configurations.

```mermaid
gitGraph
    commit id: "Feature Branch"
    branch feature/new-app
    checkout feature/new-app
    commit id: "Add App Manifests"
    commit id: "Configure Environment"
    checkout main
    merge feature/new-app
    commit id: "Auto-deploy to Dev"
    branch staging
    checkout staging
    merge main
    commit id: "Deploy to Staging"
    checkout main
    branch production
    checkout production
    merge staging
    commit id: "Deploy to Production"
```

### Workflow Steps

1. **Development**: Create feature branch, develop and test locally
2. **Integration**: Create pull request, automated CI/CD validation
3. **Review**: Code review and approval process
4. **Deployment**: Merge triggers ArgoCD deployment to target environment
5. **Monitoring**: Observe deployment status and application health

## 🚀 Application Onboarding

### Prerequisites

Before onboarding a new application:
- [ ] Application containerized with proper health checks
- [ ] Helm chart or Kubernetes manifests prepared
- [ ] Resource requirements documented
- [ ] Security requirements defined (secrets, RBAC, network policies)

### Step 1: Create Application Structure

```bash
# Create application directory structure
mkdir -p gitops/applications/my-app/{base,environments}
mkdir -p gitops/applications/my-app/environments/{dev,staging,production}
```

### Step 2: Define Base Application

Create the base Helm chart or manifests:

```yaml
# gitops/applications/my-app/base/Chart.yaml
apiVersion: v2
name: my-app
description: My Application Helm Chart
type: application
version: 0.1.0
appVersion: "1.0.0"
```

```yaml
# gitops/applications/my-app/base/values.yaml
replicaCount: 2

image:
  repository: my-app
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: my-app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: my-app-tls
      hosts:
        - my-app.example.com

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

nodeSelector: {}
tolerations: []
affinity: {}
```

### Step 3: Environment-Specific Configuration

```yaml
# gitops/applications/my-app/environments/dev/values.yaml
replicaCount: 1

image:
  tag: "dev-latest"

ingress:
  hosts:
    - host: my-app-dev.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: my-app-dev-tls
      hosts:
        - my-app-dev.example.com

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
```

```yaml
# gitops/applications/my-app/environments/production/values.yaml
replicaCount: 3

image:
  tag: "1.0.0"  # Specific version for production

ingress:
  hosts:
    - host: my-app.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 1000m
    memory: 1024Mi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
```

### Step 4: Create ArgoCD Application

```yaml
# gitops/argocd/applications/my-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-dev
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/infrastructure-repo
    targetRevision: HEAD
    path: gitops/applications/my-app/base
    helm:
      valueFiles:
        - ../environments/dev/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/infrastructure-repo
    targetRevision: staging
    path: gitops/applications/my-app/base
    helm:
      valueFiles:
        - ../environments/staging/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app-staging
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

### Step 5: Validate and Deploy

```bash
# Validate Helm chart
helm lint gitops/applications/my-app/base

# Template and review manifests
helm template my-app gitops/applications/my-app/base \
  -f gitops/applications/my-app/environments/dev/values.yaml

# Commit and push
git add gitops/applications/my-app/
git commit -m "feat: add my-app application"
git push origin feature/add-my-app
```

## 🔐 Secrets Management

We use Sealed Secrets to securely store encrypted secrets in Git.

### Creating Sealed Secrets

```bash
# Install kubeseal CLI (if not already installed)
curl -sSL https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz | tar xz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Create a regular Kubernetes secret
kubectl create secret generic my-app-secrets \
  --from-literal=database-password=supersecret \
  --from-literal=api-key=abc123 \
  --dry-run=client -o yaml > my-app-secrets.yaml

# Seal the secret
kubeseal -o yaml < my-app-secrets.yaml > my-app-sealed-secrets.yaml

# Clean up temporary file
rm my-app-secrets.yaml
```

### Using Sealed Secrets in Applications

```yaml
# gitops/applications/my-app/base/templates/sealed-secret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-app-secrets
  namespace: my-app
spec:
  encryptedData:
    database-password: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
    api-key: AgAKAoiQm7hne+3Tk4pJlzQRBQVpJfG...
  template:
    metadata:
      name: my-app-secrets
      namespace: my-app
    type: Opaque
```

```yaml
# Reference secrets in deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: my-app
        image: my-app:latest
        env:
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: my-app-secrets
              key: database-password
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: my-app-secrets
              key: api-key
```

### Managing Secrets Across Environments

```bash
# Create environment-specific sealed secrets
kubeseal --scope cluster-wide -o yaml < dev-secrets.yaml > dev-sealed-secrets.yaml
kubeseal --scope cluster-wide -o yaml < prod-secrets.yaml > prod-sealed-secrets.yaml

# Store in environment-specific directories
mv dev-sealed-secrets.yaml gitops/secrets/dev/
mv prod-sealed-secrets.yaml gitops/secrets/production/
```

## 🏠 Local Development Setup

### Prerequisites

Install required tools:

```bash
# Docker (for container builds)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
```

### Setting Up kubectl Access

```bash
# Copy kubeconfig from cluster
scp user@control-node:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Update server address
sed -i 's/127.0.0.1/your-cluster-ip/g' ~/.kube/config

# Test connection
kubectl get nodes
```

### Development Workflow

#### 1. Clone Repository
```bash
git clone https://github.com/your-org/infrastructure-repo
cd infrastructure-repo
```

#### 2. Create Feature Branch
```bash
git checkout -b feature/my-new-feature
```

#### 3. Develop and Test Locally
```bash
# Build and test your application
docker build -t my-app:dev .
docker run -p 8080:80 my-app:dev

# Test Helm chart locally
helm template my-app gitops/applications/my-app/base \
  -f gitops/applications/my-app/environments/dev/values.yaml \
  --debug
```

#### 4. Deploy to Development Environment
```bash
# Update image tag in dev values
sed -i 's/tag: .*/tag: "dev-'$(git rev-parse --short HEAD)'"/' \
  gitops/applications/my-app/environments/dev/values.yaml

# Commit and push
git add .
git commit -m "feat: update my-app to version dev-abc123"
git push origin feature/my-new-feature
```

#### 5. Monitor Deployment
```bash
# Watch ArgoCD sync status
argocd app sync my-app-dev
argocd app wait my-app-dev

# Check application status
kubectl get pods -n my-app-dev
kubectl logs -f deployment/my-app -n my-app-dev
```

## 🎯 Environment Promotion

### Development → Staging
```bash
# Create staging branch from main
git checkout main
git pull origin main
git checkout -b staging
git push origin staging

# ArgoCD will automatically sync staging environment
```

### Staging → Production
```bash
# After staging validation, promote to production
git checkout main
git merge staging
git tag v1.0.0
git push origin main --tags

# Manually trigger production deployment
argocd app sync my-app-production
```

## 🔍 Monitoring and Debugging

### Application Health Checks

```bash
# Check application status in ArgoCD
argocd app get my-app-dev

# View application logs
kubectl logs -f -l app=my-app -n my-app-dev

# Check ingress and services
kubectl get ingress,svc -n my-app-dev

# Test application endpoints
curl -k https://my-app-dev.example.com/health
```

### Debugging Deployments

```bash
# Check pod status and events
kubectl describe pod -l app=my-app -n my-app-dev

# View ArgoCD application events
argocd app get my-app-dev --output json | jq '.status.conditions'

# Check resource utilization
kubectl top pods -n my-app-dev
```

### Rolling Back Deployments

```bash
# Rollback via ArgoCD
argocd app rollback my-app-dev

# Rollback via kubectl
kubectl rollout undo deployment/my-app -n my-app-dev

# Rollback to specific revision
kubectl rollout undo deployment/my-app --to-revision=2 -n my-app-dev
```

## 📊 Performance and Resource Management

### Resource Optimization

```yaml
# Configure resource requests and limits appropriately
resources:
  requests:
    cpu: 100m      # Minimum required
    memory: 128Mi  # Minimum required
  limits:
    cpu: 500m      # Maximum allowed
    memory: 512Mi  # Maximum allowed
```

### Horizontal Pod Autoscaling

```yaml
# HPA configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## 🛡️ Security Best Practices

### Container Security
- Use non-root users in containers
- Scan images for vulnerabilities
- Use minimal base images (alpine, distroless)
- Set security contexts appropriately

### Network Security
```yaml
# Network policy example
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-app-netpol
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 5432
```

## 📚 Common Patterns and Examples

### Multi-Container Applications
```yaml
# Sidecar pattern example
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-with-sidecar
spec:
  template:
    spec:
      containers:
      - name: main-app
        image: my-app:latest
        ports:
        - containerPort: 8080
      - name: logging-sidecar
        image: fluent-bit:latest
        volumeMounts:
        - name: shared-logs
          mountPath: /logs
      volumes:
      - name: shared-logs
        emptyDir: {}
```

### Database Integration
```yaml
# Database deployment with persistent storage
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  template:
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secrets
              key: password
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
```

---

*This development guide provides the foundation for working with our GitOps-based infrastructure. For operational procedures, see the [Operations Guide](../operations/README.md).* 