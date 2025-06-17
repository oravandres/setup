# Sealed Secrets Management Guide

This guide explains how to manage secrets securely in our GitOps workflow using Bitnami Sealed Secrets.

## Overview

Sealed Secrets allows us to store encrypted secrets directly in our Git repository. The `sealed-secrets-controller` running in the cluster can decrypt these secrets and create regular Kubernetes secrets that applications can use.

### Benefits

- ✅ **GitOps Compatible**: Secrets can be stored safely in Git
- ✅ **Declarative**: Secrets are managed like any other Kubernetes resource
- ✅ **Secure**: Only the cluster can decrypt the secrets
- ✅ **Auditable**: Changes to secrets are tracked in Git history
- ✅ **Environment Specific**: Different encryption per cluster/namespace

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Developer     │    │   GitOps Repo    │    │   K8s Cluster   │
│                 │    │                  │    │                 │
│ 1. Create       │    │ 3. Store         │    │ 5. Apply &      │
│    plain secret │───▶│    sealed secret │───▶│    decrypt      │
│                 │    │                  │    │                 │
│ 2. Seal with    │    │ 4. ArgoCD sync   │    │ 6. Create K8s   │
│    kubeseal     │    │                  │    │    secret       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Directory Structure

```
gitops/secrets/
├── README.md                 # This documentation
├── dev/                      # Development environment secrets
│   └── example-app-secrets.yaml
├── staging/                  # Staging environment secrets
│   └── example-app-secrets.yaml
├── production/               # Production environment secrets
│   └── example-app-secrets.yaml
└── shared/                   # Cross-environment secrets (use carefully)
    └── shared-config.yaml
```

## Prerequisites

1. **Sealed Secrets Controller**: Must be deployed in the cluster
   ```bash
   kubectl get pods -n kube-system -l name=sealed-secrets-controller
   ```

2. **kubeseal CLI**: Install on your local machine
   ```bash
   # The tool is automatically installed by our Ansible playbook
   kubeseal --version
   ```

3. **Public Key**: Available from the cluster
   ```bash
   # Fetch the public key (done automatically by Ansible)
   kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
     -o jsonpath='{.items[0].data.tls\.crt}' | base64 -d > /tmp/sealed-secrets-public.pem
   ```

## Creating Sealed Secrets

### Method 1: Using the Ansible Script (Recommended)

We provide a helper script that automates the process:

```bash
# Create a generic secret for development
/usr/local/bin/seal-secret.sh create myapp-secrets default dev generic

# Create a TLS secret for production
/usr/local/bin/seal-secret.sh create tls-cert default production tls

# Create a Docker registry secret for staging
/usr/local/bin/seal-secret.sh create registry-creds default staging docker-registry
```

### Method 2: Manual Process

#### Step 1: Create a regular Kubernetes secret (don't apply it!)

```bash
# For generic secrets
kubectl create secret generic myapp-secrets \
  --namespace=default \
  --from-literal=database-password="supersecret123" \
  --from-literal=api-key="api-key-456" \
  --dry-run=client -o yaml > /tmp/myapp-secret.yaml

# For TLS secrets
kubectl create secret tls tls-secret \
  --namespace=default \
  --cert=path/to/cert.crt \
  --key=path/to/key.key \
  --dry-run=client -o yaml > /tmp/tls-secret.yaml

# For Docker registry secrets
kubectl create secret docker-registry registry-secret \
  --namespace=default \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myuser \
  --docker-password=mypass \
  --docker-email=myemail@example.com \
  --dry-run=client -o yaml > /tmp/registry-secret.yaml
```

#### Step 2: Seal the secret

```bash
# Seal the secret using the public key
kubeseal --cert /tmp/sealed-secrets-public.pem \
  --format=yaml < /tmp/myapp-secret.yaml > gitops/secrets/dev/myapp-secrets.yaml
```

#### Step 3: Clean up temporary files

```bash
rm /tmp/myapp-secret.yaml
```

### Method 3: Using Raw Values

For individual secret values:

```bash
# Seal individual values
echo -n 'supersecret123' | kubeseal --raw \
  --from-file=/dev/stdin \
  --name=myapp-secrets \
  --namespace=default \
  --cert /tmp/sealed-secrets-public.pem
```

## Secret Scopes

Sealed Secrets supports different encryption scopes:

### Strict Scope (Default - Recommended)
- Secret can only be decrypted by the same name and namespace
- Most secure option
- Used by default

```yaml
metadata:
  annotations:
    sealedsecrets.bitnami.com/cluster-wide: "false"
    sealedsecrets.bitnami.com/namespace-wide: "false"
```

### Namespace-wide Scope
- Secret can be decrypted by any secret name in the same namespace
- Use with caution

```bash
kubeseal --scope namespace-wide --cert /tmp/sealed-secrets-public.pem < secret.yaml
```

### Cluster-wide Scope
- Secret can be decrypted anywhere in the cluster
- Use only for truly global secrets

```bash
kubeseal --scope cluster-wide --cert /tmp/sealed-secrets-public.pem < secret.yaml
```

## Environment-Specific Workflows

### Development Environment

- **Location**: `gitops/secrets/dev/`
- **Encryption**: Per-cluster public key
- **Security**: Relaxed for development ease
- **Process**: Direct commit to main branch

```bash
# Example: Create development database secret
/usr/local/bin/seal-secret.sh create db-creds default dev generic
# Enter credentials when prompted
# Commit the generated file
git add gitops/secrets/dev/db-creds-sealed-secret.yaml
git commit -m "Add development database credentials"
```

### Staging Environment

- **Location**: `gitops/secrets/staging/`
- **Encryption**: Per-cluster public key
- **Security**: Production-like testing
- **Process**: PR review required

```bash
# Example: Create staging API keys
/usr/local/bin/seal-secret.sh create api-secrets default staging generic
# Create PR for review
git checkout -b "add-staging-api-secrets"
git add gitops/secrets/staging/api-secrets-sealed-secret.yaml
git commit -m "Add staging API secrets"
git push origin add-staging-api-secrets
# Open PR for review
```

### Production Environment

- **Location**: `gitops/secrets/production/`
- **Encryption**: Per-cluster public key
- **Security**: Maximum security
- **Process**: Mandatory PR review + approval

```bash
# Example: Create production TLS certificate
/usr/local/bin/seal-secret.sh create wildcard-tls kube-system production tls
# Mandatory review process
git checkout -b "add-production-tls"
git add gitops/secrets/production/wildcard-tls-sealed-secret.yaml
git commit -m "Add production wildcard TLS certificate"
git push origin add-production-tls
# Open PR with detailed description
# Require 2+ approvals before merge
```

## Using Secrets in Applications

### In Helm Charts

```yaml
# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        env:
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: myapp-secrets  # This will be created by SealedSecret
              key: database-password
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: myapp-secrets
              key: api-key
        volumeMounts:
        - name: tls-certs
          mountPath: /etc/ssl/certs
          readOnly: true
      volumes:
      - name: tls-certs
        secret:
          secretName: tls-secret  # Created from TLS SealedSecret
```

### In Raw Kubernetes Manifests

```yaml
# application.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: myapp
        envFrom:
        - secretRef:
            name: myapp-secrets  # References the unsealed secret
```

## Best Practices

### Secret Naming Convention

```
<application>-<type>-<environment>
```

Examples:
- `webapp-db-secrets` (for webapp database credentials)
- `api-service-keys` (for API service keys)
- `wildcard-tls-cert` (for TLS certificates)

### File Organization

```
gitops/secrets/
├── dev/
│   ├── webapp-db-secrets.yaml
│   ├── api-service-keys.yaml
│   └── monitoring-credentials.yaml
├── staging/
│   ├── webapp-db-secrets.yaml
│   ├── api-service-keys.yaml
│   └── monitoring-credentials.yaml
└── production/
    ├── webapp-db-secrets.yaml
    ├── api-service-keys.yaml
    ├── monitoring-credentials.yaml
    └── wildcard-tls-cert.yaml
```

### Security Guidelines

1. **Never commit plain secrets** to Git
2. **Use strict scope** unless specifically needed
3. **Rotate secrets regularly** (especially production)
4. **Review all secret changes** via PR process
5. **Audit secret access** through Kubernetes RBAC
6. **Monitor secret usage** with cluster monitoring
7. **Backup encryption keys** securely

### Secret Rotation

```bash
# 1. Create new sealed secret with updated values
/usr/local/bin/seal-secret.sh create myapp-secrets default production generic

# 2. Commit and deploy the new secret
git add gitops/secrets/production/myapp-secrets-sealed-secret.yaml
git commit -m "Rotate production secrets"

# 3. Restart applications to pick up new secrets
kubectl rollout restart deployment/myapp -n default

# 4. Verify the rotation worked
kubectl get secret myapp-secrets -o yaml
```

## Troubleshooting

### Common Issues

#### 1. SealedSecret not creating Secret

**Symptoms**: SealedSecret exists but no corresponding Secret is created

**Solutions**:
```bash
# Check controller logs
kubectl logs -n kube-system -l name=sealed-secrets-controller

# Check SealedSecret status
kubectl describe sealedsecret myapp-secrets

# Verify controller is running
kubectl get pods -n kube-system -l name=sealed-secrets-controller
```

#### 2. Wrong encryption key

**Symptoms**: `cannot unseal` errors in controller logs

**Solutions**:
```bash
# Fetch current public key
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o jsonpath='{.items[0].data.tls\.crt}' | base64 -d > /tmp/sealed-secrets-public.pem

# Re-encrypt with correct key
kubeseal --cert /tmp/sealed-secrets-public.pem --format=yaml < original-secret.yaml > sealed-secret.yaml
```

#### 3. Namespace/Name mismatch

**Symptoms**: Secret not appearing in expected namespace

**Solutions**:
- Verify namespace in SealedSecret matches target
- Check secret name matches exactly
- Ensure proper scope is used

### Debugging Commands

```bash
# Check sealed secrets status
kubectl get sealedsecrets -A

# View controller logs
kubectl logs -n kube-system deployment/sealed-secrets-controller

# Check regular secrets created from sealed secrets
kubectl get secrets -A | grep -v "kubernetes.io"

# Validate a sealed secret file
kubeseal --validate < sealed-secret.yaml

# Get public key fingerprint
kubeseal --print-certs --cert /tmp/sealed-secrets-public.pem
```

## Security Considerations

### Key Management

- **Encryption keys** are automatically generated by the controller
- **Private keys** never leave the cluster
- **Public keys** are safe to share and store in Git
- **Key rotation** should be planned (affects all existing secrets)

### Access Control

```yaml
# Example RBAC for secret management
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: sealed-secret-manager
rules:
- apiGroups: ["bitnami.com"]
  resources: ["sealedsecrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
```

### Backup and Recovery

1. **Backup SealedSecret manifests**: Stored in Git (encrypted)
2. **Backup controller private key**: 
   ```bash
   kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml
   ```
3. **Store backup securely**: Use encrypted storage outside the cluster

### Disaster Recovery

If the controller private key is lost:

1. **Restore from backup**:
   ```bash
   kubectl apply -f sealed-secrets-key-backup.yaml
   kubectl rollout restart deployment/sealed-secrets-controller -n kube-system
   ```

2. **If no backup exists**:
   - All existing SealedSecrets become unusable
   - Must re-create all secrets with new public key
   - This is why key backup is critical

## Integration with ArgoCD

SealedSecrets work seamlessly with ArgoCD:

```yaml
# ArgoCD Application for secrets
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sealed-secrets
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/k3s-homelab-setup
    targetRevision: HEAD
    path: gitops/secrets
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Monitoring and Alerting

Monitor SealedSecrets controller health:

```yaml
# Prometheus alert example
groups:
- name: sealed-secrets
  rules:
  - alert: SealedSecretsControllerDown
    expr: up{job="sealed-secrets-controller"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Sealed Secrets controller is down"
      description: "The Sealed Secrets controller has been down for more than 5 minutes"
      
  - alert: SealedSecretDecryptionFailure
    expr: increase(sealed_secrets_unsealing_errors_total[5m]) > 0
    labels:
      severity: warning
    annotations:
      summary: "Sealed Secret decryption failed"
      description: "Failed to decrypt {{ $labels.name }} in namespace {{ $labels.namespace }}"
```

## References

- [Bitnami Sealed Secrets Documentation](https://sealed-secrets.netlify.app/)
- [Sealed Secrets GitHub Repository](https://github.com/bitnami-labs/sealed-secrets)
- [GitOps with ArgoCD and Sealed Secrets](https://argoproj.github.io/argo-cd/)

---

**Need Help?**
- Check the troubleshooting section above
- Review controller logs: `kubectl logs -n kube-system -l name=sealed-secrets-controller`
- Consult the official documentation
- Open an issue in the project repository 