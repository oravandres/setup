
# K3s Homelab Setup
**Production-ready Kubernetes homelab with GitOps, observability, and high availability.**

[![Infrastructure](https://img.shields.io/badge/Infrastructure-K3s-blue)](https://k3s.io/)
[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-orange)](https://argoproj.github.io/cd/)
[![Monitoring](https://img.shields.io/badge/Monitoring-Prometheus-red)](https://prometheus.io/)
[![Storage](https://img.shields.io/badge/Storage-Longhorn-green)](https://longhorn.io/)
## 🏗️ Architecture
**7-node high-availability cluster** with complete cloud-native platform:

```
┌─────────────────┬─────────────────┬─────────────────┐
│   Control Plane │      Workers    │    Services     │
├─────────────────┼─────────────────┼─────────────────┤
│ dream-machine   │ pi-n1           │ MetalLB         │
│ pi-m2           │ pi-n2           │ Ingress-NGINX   │
│ pi-m3           │ pi-n3           │ Longhorn        │
│                 │ pi-n4           │ ArgoCD          │
│                 │                 │ Prometheus      │
└─────────────────┴─────────────────┴─────────────────┘
```

**Key Features:**
- **HA Control Plane** with HAProxy + keepalived VIP
- **GitOps Deployment** via ArgoCD with automated sync
- **Distributed Storage** using Longhorn with 3-replica redundancy
- **Complete Observability** with Prometheus, Grafana, and Loki
- **Automated TLS** via cert-manager and Let's Encrypt
- **Load Balancing** with MetalLB Layer 2 configuration
## 🚀 Quick Start

### Prerequisites

```bash

# Required tools

sudo apt install ansible git kubectl helm
# Clone repository

git clone https://github.com/oravandres/setup.git
cd setup
```
### 1. Deploy Infrastructure

```bash

# Deploy full cluster (production)

ansible-playbook -i infrastructure/inventory/production/hosts.yaml infrastructure/playbooks/site.yaml
# Or single-node development

ansible-playbook -i infrastructure/inventory/dev/hosts.yaml infrastructure/playbooks/site.yaml
```
### 2. Access Services

```bash

# Get cluster status

kubectl get nodes -o wide
# Access ArgoCD

kubectl port-forward svc/argocd-server -n argocd 8080:443

# URL: https://localhost:8080
# User: admin | Password: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)

# Access Grafana

kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

# URL: http://localhost:3000
# User: admin | Password: prom-operator

```
### 3. Deploy Applications

```bash

# Deploy via GitOps

kubectl apply -f gitops/argocd/infrastructure-appset.yaml
kubectl apply -f gitops/argocd/applications-appset.yaml
# Check deployment status

kubectl get applications -n argocd
```
## 📁 Project Structure
```
setup/
├── infrastructure/          # Ansible infrastructure automation
│   ├── inventory/          # Environment-specific configurations
│   │   ├── dev/           # Localhost development setup
│   │   └── production/    # Full 7-node cluster setup
│   ├── playbooks/         # Main deployment playbooks
│   └── roles/             # Reusable Ansible roles
├── gitops/                # GitOps configurations
│   ├── argocd/           # ArgoCD ApplicationSets
│   ├── applications/     # Application manifests
│   ├── environments/     # Environment-specific values
│   └── infrastructure/   # Platform component charts
├── docs/                 # Comprehensive documentation
└── scripts/             # Utility and management scripts
```
## 🌍 Environments

### Development (Localhost)

**Purpose:** Single-node development and testing
```bash

# Deploy dev environment

ansible-playbook -i infrastructure/inventory/dev/hosts.yaml infrastructure/playbooks/site.yaml
# Features: Minimal resources, local storage, NodePort services

```
### Production (7-node Cluster)

**Purpose:** Full production workloads
```bash

# Deploy production environment

ansible-playbook -i infrastructure/inventory/production/hosts.yaml infrastructure/playbooks/site.yaml
# Features: HA control plane, Longhorn storage, LoadBalancer services

```
## 🔧 Common Operations

### Cluster Management

```bash

# Check cluster health

kubectl get nodes,pods -A
# Scale applications

kubectl scale deployment my-app --replicas=3
# View logs

kubectl logs -f deployment/my-app -n my-namespace
```
### GitOps Operations

```bash

# Sync applications manually

kubectl patch application my-app -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' --type=merge
# Check sync status

kubectl get applications -n argocd -o wide
```
### Storage Management

```bash

# Check Longhorn status

kubectl get volumes -n longhorn-system
# Create persistent volume

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  storageClassName: longhorn
EOF
```
### Monitoring & Alerts

```bash

# Access Prometheus

kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
# Access AlertManager

kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093
# Check alert rules

kubectl get prometheusrules -A
```
## 🔐 Security Features
- **TLS Everywhere:** Automatic certificate management with cert-manager
- **Sealed Secrets:** GitOps-safe secret management
- **Network Policies:** Micro-segmentation and traffic control
- **RBAC:** Role-based access control for all components
- **Pod Security:** Standards enforcement across workloads
## 📊 Observability Stack
| Component | Purpose | Access |
|-----------|---------|--------|
| **Prometheus** | Metrics collection | `:9090` |
| **Grafana** | Visualization | `:3000` |
| **AlertManager** | Alert routing | `:9093` |
| **Loki** | Log aggregation | `:3100` |
## 🛠️ Troubleshooting

### Common Issues

```bash

# Node not ready

kubectl describe node <node-name>
kubectl get events --sort-by=.metadata.creationTimestamp
# Pod failures

kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
# Storage issues

kubectl get pv,pvc -A
kubectl describe pvc <pvc-name> -n <namespace>
```
### Recovery Procedures

```bash

# Restart cluster components

kubectl rollout restart deployment/coredns -n kube-system
# Recreate failed pods

kubectl delete pod <pod-name> -n <namespace>
# Check cluster certificates

kubectl get certificatesigningrequests
```
## 📚 Documentation
- **[Architecture](docs/architecture/README.md)** - Detailed system design and components
- **[Operations](docs/operations/README.md)** - Day-to-day operational procedures
- **[Development](docs/development/README.md)** - Development workflows and guidelines
- **[Security](docs/security/README.md)** - Security configurations and best practices
- **[Runbooks](docs/runbooks/README.md)** - Step-by-step operational procedures
## 🤝 Contributing
1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** changes: `git commit -m 'Add amazing feature'`
4. **Push** to branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request
## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**⭐ Star this repo if it helped you build your homelab!**
