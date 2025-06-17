# GitOps Workflow Documentation

## Overview

This document describes the GitOps workflow for the K3s homelab cluster, including how infrastructure and application changes are proposed, reviewed, and deployed across environments.

## Repository Structure

```
gitops/
├── applications/           # Application workloads
│   └── example-app/       # Example application
├── infrastructure/        # Core infrastructure components
│   ├── Chart.yaml        # Infrastructure umbrella chart
│   └── values.yaml       # Default infrastructure values
├── environments/          # Environment-specific configurations
│   ├── dev/
│   │   └── values.yaml   # Development environment values
│   ├── staging/
│   │   └── values.yaml   # Staging environment values
│   └── production/
│       └── values.yaml   # Production environment values
├── argocd/               # ArgoCD ApplicationSets and configs
│   ├── infrastructure-appset.yaml
│   └── applications-appset.yaml
└── secrets/              # Sealed secrets and external secrets
```

## GitOps Workflow

### 1. Development Process

#### For Infrastructure Changes:
1. **Create Feature Branch**: Create a new branch from `main`
   ```bash
   git checkout -b feature/add-monitoring-stack
   ```

2. **Make Changes**: Modify configurations in appropriate directories:
   - Update `gitops/infrastructure/` for new infrastructure components
   - Modify `gitops/environments/{env}/values.yaml` for environment-specific changes
   - Add new applications in `gitops/applications/`

3. **Test Locally**: Validate Helm charts and YAML syntax
   ```bash
   # Validate infrastructure chart
   helm lint gitops/infrastructure/
   
   # Template and validate manifests
   helm template test gitops/infrastructure/ \
     -f gitops/environments/dev/values.yaml \
     --validate
   ```

4. **Commit Changes**: Create clear, descriptive commits
   ```bash
   git add .
   git commit -m "feat(monitoring): add Prometheus and Grafana to infrastructure stack"
   ```

#### For Application Changes:
1. **Application Development**: Develop and test applications locally
2. **Chart Creation**: Create or update Helm charts in `gitops/applications/`
3. **Environment Configuration**: Update environment values as needed
4. **Testing**: Validate charts and test deployments

### 2. Review Process

#### Pull Request Requirements:
- **Clear Description**: Describe what changes are being made and why
- **Environment Impact**: Specify which environments are affected
- **Testing Evidence**: Include validation results and testing screenshots
- **Security Review**: For production changes, require security team approval

#### Automated Checks:
- Helm chart linting
- YAML syntax validation
- Security scanning (if applicable)
- Dry-run deployment validation

### 3. Deployment Pipeline

#### Environment Promotion Flow:
```
Developer → Dev Environment → Staging Environment → Production Environment
    ↓            ↓                    ↓                      ↓
   Local      Auto-Deploy         Auto-Deploy           Manual Deploy
  Testing    (on PR merge)      (after dev validation)  (manual approval)
```

#### Automatic Deployments:
- **Dev Environment**: Automatically deploys on merge to `main`
- **Staging Environment**: Automatically deploys after successful dev deployment
- **Production Environment**: Manual deployment with approval process

### 4. ArgoCD ApplicationSet Behavior

#### Infrastructure ApplicationSet:
- **Scope**: Core infrastructure components (MetalLB, cert-manager, monitoring, etc.)
- **Deployment**: Automatic across all environments with environment-specific values
- **Sync Policy**: Auto-prune and self-heal enabled
- **Retry Strategy**: Exponential backoff with 5 retry attempts

#### Applications ApplicationSet:
- **Scope**: Application workloads and services
- **Deployment**: Environment-dependent (auto for dev/staging, manual for production)
- **Namespace Strategy**: Environment-specific suffixes (`app-dev`, `app-staging`, `app`)
- **Sync Policy**: Auto-sync for non-production, manual for production

### 5. Environment Configuration

#### Development Environment:
- **Purpose**: Active development and feature testing
- **Characteristics**:
  - Reduced resource limits
  - Simplified configurations
  - Disabled security policies for flexibility
  - Local storage instead of distributed storage

#### Staging Environment:
- **Purpose**: Pre-production testing and validation
- **Characteristics**:
  - Production-like configurations
  - Reduced resource allocations
  - Security policies enabled
  - Regular backups enabled

#### Production Environment:
- **Purpose**: Live workloads and services
- **Characteristics**:
  - Full resource allocations
  - Complete security hardening
  - HA configurations enabled
  - Comprehensive monitoring and alerting
  - External secrets management

### 6. Secret Management

#### Development & Staging:
- **Method**: Plain Kubernetes secrets (acceptable for non-production)
- **Location**: Committed to repository (with dummy/test values)

#### Production:
- **Method**: External Secrets Operator with Vault backend
- **Location**: Secrets stored in external Vault instance
- **Access**: Service accounts with minimal required permissions

### 7. Rollback Procedures

#### Automated Rollback:
- ArgoCD will automatically detect and sync to the desired state
- Failed deployments trigger automatic rollback after retry attempts

#### Manual Rollback:
1. **Identify Issue**: Monitor ArgoCD UI and application metrics
2. **Revert Changes**: 
   ```bash
   git revert <commit-hash>
   git push origin main
   ```
3. **Force Sync**: If needed, trigger manual sync in ArgoCD UI
4. **Verify**: Confirm services are restored

### 8. Monitoring and Observability

#### ArgoCD Monitoring:
- Application health status
- Sync status and history
- Resource deployment status

#### Application Monitoring:
- Prometheus metrics collection
- Grafana dashboards
- Alertmanager notifications

#### Infrastructure Monitoring:
- Cluster resource utilization
- Node health and performance
- Storage and network metrics

### 9. Best Practices

#### Commit Guidelines:
- Use conventional commit format: `type(scope): description`
- Keep changes atomic and focused
- Include clear commit messages

#### Chart Development:
- Follow Helm best practices
- Use semantic versioning
- Include comprehensive values.yaml documentation
- Implement health checks and readiness probes

#### Security:
- Never commit production secrets
- Use least-privilege access
- Regular security scanning
- Network policies in production

#### Testing:
- Validate charts before committing
- Test in dev environment first
- Perform staging validation
- Monitor production deployments

### 10. Troubleshooting

#### Common Issues:
- **Sync Failures**: Check ArgoCD logs and event messages
- **Resource Conflicts**: Verify namespace and resource naming
- **Permission Issues**: Check RBAC and service account permissions
- **Chart Errors**: Validate Helm syntax and dependencies

#### Debug Commands:
```bash
# Check ArgoCD application status
kubectl get applications -n argocd

# View application details
kubectl describe application <app-name> -n argocd

# Check pod status
kubectl get pods -n <namespace>

# View logs
kubectl logs -n <namespace> <pod-name>
```

## Getting Started

1. **Clone Repository**: Clone the homelab setup repository
2. **Review Structure**: Familiarize yourself with the GitOps directory structure
3. **Set Up Development**: Configure local Helm and kubectl tools
4. **Create Branch**: Start with a feature branch for changes
5. **Test Changes**: Validate locally before committing
6. **Submit PR**: Create pull request with clear description
7. **Monitor Deployment**: Watch ArgoCD for deployment status

For questions or support, contact the homelab administration team. 