# Operations Guide

**Day-to-day operational procedures for K3s homelab cluster management.**

## 🎯 Overview

This guide covers essential operational tasks for maintaining the K3s homelab cluster, including monitoring, troubleshooting, scaling, backup/restore, and routine maintenance procedures.

## 📊 Daily Operations

### Cluster Health Checks

**Morning Health Check Routine:**
```bash
#!/bin/bash
# Daily cluster health check script

echo "=== K3s Cluster Health Check ==="
echo "Date: $(date)"
echo

# Node status
echo "🖥️  Node Status:"
kubectl get nodes -o wide
echo

# Pod health across all namespaces
echo "🚀 Pod Health Summary:"
kubectl get pods -A --field-selector=status.phase!=Running | head -10
echo

# Critical service status
echo "⚙️  Critical Services:"
kubectl get pods -n kube-system | grep -E "(coredns|metrics-server)"
kubectl get pods -n argocd | grep argocd-server
kubectl get pods -n monitoring | grep -E "(prometheus|grafana)"
kubectl get pods -n longhorn-system | grep longhorn-manager | head -3
echo

# Storage status
echo "💾 Storage Health:"
kubectl get storageclass
kubectl get pv | grep -v Available | head -5
echo

# LoadBalancer services
echo "🔄 LoadBalancer Services:"
kubectl get svc -A --field-selector=spec.type=LoadBalancer
echo

# Recent events (last 1 hour)
echo "📋 Recent Events:"
kubectl get events --sort-by=.metadata.creationTimestamp -A | tail -10
```

**Save as `/usr/local/bin/cluster-health-check` and run daily:**
```bash
sudo chmod +x /usr/local/bin/cluster-health-check
cluster-health-check
```

### Service Monitoring

**Check specific service health:**
```bash
# ArgoCD status
kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status"

# Prometheus targets
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090 &
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health != "up") | .labels.job'

# Grafana dashboards
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80 &
curl -s http://admin:prom-operator@localhost:3000/api/health

# Longhorn storage
kubectl get volumes -n longhorn-system -o custom-columns="NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness"
```

## 🔧 Routine Maintenance

### Weekly Maintenance Tasks

**System Updates (via Ansible):**
```bash
# Update all nodes
ansible all -i infrastructure/inventory/production/hosts.yaml \
  -m shell -a "sudo apt update && sudo apt upgrade -y" \
  --become

# Restart nodes if kernel updates (one at a time)
ansible pi-n1 -i infrastructure/inventory/production/hosts.yaml \
  -m reboot --become

# Wait and verify node is back
kubectl wait --for=condition=Ready node/pi-n1 --timeout=300s
```

**Certificate Renewal Check:**
```bash
# Check certificate expiration
kubectl get certificates -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status,AGE:.metadata.creationTimestamp"

# Force certificate renewal if needed
kubectl delete certificate <cert-name> -n <namespace>
# cert-manager will automatically recreate
```

**Log Rotation and Cleanup:**
```bash
# Clean up old container logs (on each node)
ansible all -i infrastructure/inventory/production/hosts.yaml \
  -m shell -a "sudo find /var/log/containers/ -name '*.log' -mtime +7 -delete" \
  --become

# Clean up old pod logs in Loki (if retention policy isn't working)
kubectl exec -n monitoring loki-0 -- /usr/bin/loki -config.file=/etc/loki/loki.yaml -target=table-manager -table-manager.retention-deletes-enabled=true
```

### Monthly Maintenance Tasks

**Backup Verification:**
```bash
# Verify etcd backups
ansible pi-m2 -i infrastructure/inventory/production/hosts.yaml \
  -m shell -a "sudo k3s etcd-snapshot ls" --become

# Test backup restore (on dev environment)
ansible localhost -i infrastructure/inventory/dev/hosts.yaml \
  -m shell -a "sudo k3s etcd-snapshot restore /path/to/backup" --become
```

**Security Updates:**
```bash
# Update K3s version (rolling update)
ansible-playbook -i infrastructure/inventory/production/hosts.yaml \
  infrastructure/playbooks/upgrade-k3s.yaml

# Update Helm charts
helm repo update
helm list -A -o json | jq -r '.[] | "\(.name) \(.namespace)"' | while read name namespace; do
  echo "Checking $name in $namespace..."
  helm upgrade $name $name --namespace $namespace --reuse-values
done
```

## 🚨 Incident Response

### Emergency Procedures

**Cluster-Wide Outage:**
```bash
# 1. Check node connectivity
ansible all -i infrastructure/inventory/production/hosts.yaml -m ping

# 2. Check K3s service status on control nodes
ansible pi-m2,pi-m3,dream-machine -i infrastructure/inventory/production/hosts.yaml \
  -m shell -a "sudo systemctl status k3s" --become

# 3. Restart K3s if needed (one control node at a time)
ansible pi-m2 -i infrastructure/inventory/production/hosts.yaml \
  -m systemd -a "name=k3s state=restarted" --become

# 4. Wait for cluster to stabilize
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# 5. Verify critical services
kubectl get pods -n kube-system,argocd,monitoring
```

**Storage System Failure:**
```bash
# 1. Check Longhorn system health
kubectl get pods -n longhorn-system
kubectl get volumes -n longhorn-system

# 2. Check node storage status
ansible all -i infrastructure/inventory/production/hosts.yaml \
  -m shell -a "df -h /opt/longhorn" --become

# 3. Restart Longhorn if needed
kubectl rollout restart daemonset/longhorn-manager -n longhorn-system
kubectl rollout restart deployment/longhorn-ui -n longhorn-system

# 4. Verify volume attachments
kubectl get volumeattachments
```

**Network Connectivity Issues:**
```bash
# 1. Check MetalLB status
kubectl get pods -n metallb-system
kubectl get ipaddresspools -n metallb-system

# 2. Test ingress connectivity
kubectl get ingress -A
kubectl get svc -A --field-selector=spec.type=LoadBalancer

# 3. Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default.svc.cluster.local

# 4. Restart networking components if needed
kubectl rollout restart daemonset/ingress-nginx-controller -n ingress-nginx
kubectl rollout restart daemonset/metallb-speaker -n metallb-system
```

### Troubleshooting Common Issues

**Pod Stuck in Pending State:**
```bash
# Check pod events and describe
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl top nodes
kubectl describe node <node-name>

# Check storage class and PVCs
kubectl get storageclass
kubectl get pvc -n <namespace>

# Common fixes:
# - Scale down other pods: kubectl scale deployment <name> --replicas=0
# - Delete failed PVCs: kubectl delete pvc <pvc-name>
# - Restart kubelet: ansible <node> -m systemd -a "name=kubelet state=restarted" --become
```

**Application Not Accessible:**
```bash
# Check ingress configuration
kubectl get ingress -n <namespace>
kubectl describe ingress <ingress-name> -n <namespace>

# Check service endpoints
kubectl get endpoints -n <namespace>
kubectl describe service <service-name> -n <namespace>

# Test internal connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -qO- http://<service-name>.<namespace>.svc.cluster.local

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

**ArgoCD Sync Issues:**
```bash
# Check application status
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd

# Force refresh and sync
kubectl patch application <app-name> -n argocd \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}' \
  --type=merge

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Reset application if needed
kubectl delete application <app-name> -n argocd
kubectl apply -f gitops/argocd/applications-appset.yaml
```

## 📈 Scaling Operations

### Horizontal Scaling

**Scale Applications:**
```bash
# Scale deployment manually
kubectl scale deployment <app-name> --replicas=5 -n <namespace>

# Enable HPA for automatic scaling
kubectl autoscale deployment <app-name> --cpu-percent=70 --min=2 --max=10 -n <namespace>

# Check HPA status
kubectl get hpa -n <namespace>
kubectl describe hpa <app-name> -n <namespace>
```

**Add Worker Nodes:**
```bash
# 1. Prepare new node with Ansible
ansible-playbook -i infrastructure/inventory/production/hosts.yaml \
  infrastructure/playbooks/add-node.yaml \
  --extra-vars "target_node=pi-n5"

# 2. Verify node joined
kubectl get nodes -o wide

# 3. Label node appropriately
kubectl label node pi-n5 node-role.kubernetes.io/worker=true
kubectl label node pi-n5 nodepool=workers

# 4. Test workload scheduling
kubectl run test-pod --image=nginx --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"pi-n5"}}}'
```

### Vertical Scaling

**Increase Resource Limits:**
```bash
# Update deployment resources
kubectl patch deployment <app-name> -n <namespace> \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container-name>","resources":{"requests":{"cpu":"500m","memory":"1Gi"},"limits":{"cpu":"1000m","memory":"2Gi"}}}]}}}}'

# Install VPA for automatic vertical scaling
kubectl apply -f https://github.com/kubernetes/autoscaler/releases/latest/download/vpa-release.yaml

# Create VPA for application
kubectl apply -f - <<EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: <app-name>-vpa
  namespace: <namespace>
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: <app-name>
  updatePolicy:
    updateMode: "Auto"
EOF
```

## 💾 Backup and Recovery

### Automated Backup Procedures

**etcd Backup (Daily via Cron):**
```bash
# Create backup script
cat > /usr/local/bin/k3s-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/k3s-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="k3s-backup-${DATE}"

mkdir -p ${BACKUP_DIR}
sudo k3s etcd-snapshot save ${BACKUP_DIR}/${BACKUP_NAME}

# Keep only last 7 days of backups
find ${BACKUP_DIR} -name "k3s-backup-*" -mtime +7 -delete

# Upload to S3 (if configured)
# aws s3 cp ${BACKUP_DIR}/${BACKUP_NAME} s3://my-backup-bucket/k3s/
EOF

sudo chmod +x /usr/local/bin/k3s-backup.sh

# Add to crontab (run daily at 2 AM)
echo "0 2 * * * /usr/local/bin/k3s-backup.sh" | sudo crontab -
```

**Application Data Backup:**
```bash
# Backup persistent volumes using Longhorn
kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: RecurringJob
metadata:
  name: backup-daily
  namespace: longhorn-system
spec:
  cron: "0 3 * * *"
  task: "backup"
  groups:
  - "production"
  retain: 7
  concurrency: 2
EOF

# Manual volume backup
kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Backup
metadata:
  name: manual-backup-$(date +%s)
  namespace: longhorn-system
spec:
  snapshotName: "snapshot-$(date +%s)"
  labels:
    "backup-type": "manual"
EOF
```

### Recovery Procedures

**Cluster Recovery from etcd Backup:**
```bash
# 1. Stop K3s on all nodes
ansible all -i infrastructure/inventory/production/hosts.yaml \
  -m systemd -a "name=k3s state=stopped" --become

# 2. Restore etcd backup on first control node
ansible pi-m2 -i infrastructure/inventory/production/hosts.yaml \
  -m shell -a "sudo k3s etcd-snapshot restore /opt/k3s-backups/k3s-backup-YYYYMMDD_HHMMSS" \
  --become

# 3. Start K3s on first control node
ansible pi-m2 -i infrastructure/inventory/production/hosts.yaml \
  -m systemd -a "name=k3s state=started" --become

# 4. Wait for cluster to be ready
kubectl wait --for=condition=Ready nodes --timeout=300s

# 5. Start remaining nodes
ansible pi-m3,dream-machine -i infrastructure/inventory/production/hosts.yaml \
  -m systemd -a "name=k3s state=started" --become

# 6. Verify cluster state
kubectl get nodes -o wide
kubectl get pods -A
```

**Application Recovery:**
```bash
# 1. Restore from Longhorn backup
kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Volume
metadata:
  name: restored-volume
  namespace: longhorn-system
spec:
  fromBackup: "backup://backup-name"
  numberOfReplicas: 3
  size: "10Gi"
EOF

# 2. Update application to use restored volume
kubectl patch deployment <app-name> -n <namespace> \
  -p '{"spec":{"template":{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"restored-pvc"}}]}}}}'

# 3. Verify application functionality
kubectl get pods -n <namespace>
kubectl logs -f deployment/<app-name> -n <namespace>
```

## 🔍 Monitoring and Alerting

### Prometheus Queries for Operations

**Critical Infrastructure Metrics:**
```promql
# Node CPU usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod restart rate
increase(kube_pod_container_status_restarts_total[1h])

# Persistent volume usage
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100

# ArgoCD application health
argocd_app_health_status{health_status!="Healthy"}
```

**Set up Alert Rules:**
```yaml
# prometheus-alerts.yaml
groups:
- name: infrastructure.rules
  rules:
  - alert: NodeDown
    expr: up{job="node-exporter"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Node {{ $labels.instance }} is down"
      
  - alert: HighCPUUsage
    expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "High CPU usage on {{ $labels.instance }}"
      
  - alert: PodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod {{ $labels.pod }} is crash looping"
```

### Grafana Dashboard Management

**Import Essential Dashboards:**
```bash
# Import community dashboards
curl -s https://grafana.com/api/dashboards/1860/revisions/27/download | \
  kubectl create configmap node-exporter-dashboard --from-file=dashboard.json=/dev/stdin -n monitoring

# Create custom dashboard for K3s
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: k3s-cluster-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  k3s-cluster.json: |
    {
      "dashboard": {
        "title": "K3s Cluster Overview",
        "panels": [
          {
            "title": "Node Status",
            "type": "stat",
            "targets": [
              {
                "expr": "kube_node_status_condition{condition=\"Ready\",status=\"true\"}"
              }
            ]
          }
        ]
      }
    }
EOF
```

## 🔐 Security Operations

### Certificate Management

**Monitor Certificate Expiration:**
```bash
# Check all certificates
kubectl get certificates -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter"

# Get certificates expiring in next 30 days
kubectl get certificates -A -o json | \
  jq -r '.items[] | select(.status.notAfter != null) | select(((.status.notAfter | fromdateiso8601) - now) < 2592000) | "\(.metadata.namespace)/\(.metadata.name) expires \(.status.notAfter)"'
```

**Rotate Certificates:**
```bash
# Force certificate renewal
kubectl delete certificate <cert-name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Verify new certificate
kubectl get certificate <cert-name> -n <namespace> -o yaml
```

### Access Control Auditing

**Review RBAC Permissions:**
```bash
# List all cluster roles
kubectl get clusterroles

# Check user permissions
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:<service-account>

# Audit recent authentication events
kubectl get events --field-selector reason=FailedMount,reason=Unauthorized -A
```

### Security Scanning

**Scan for Vulnerabilities:**
```bash
# Install and run trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan cluster for vulnerabilities
trivy k8s --report summary cluster

# Scan specific images
trivy image nginx:latest
```

## 📋 Operational Checklists

### Daily Checklist
- [ ] Run cluster health check script
- [ ] Review Grafana dashboards for anomalies
- [ ] Check ArgoCD application sync status
- [ ] Verify backup completion
- [ ] Review recent alerts and events

### Weekly Checklist
- [ ] Update system packages on all nodes
- [ ] Review certificate expiration dates
- [ ] Clean up old logs and temporary files
- [ ] Test backup restore procedure (dev environment)
- [ ] Review resource utilization trends

### Monthly Checklist
- [ ] Update K3s version if available
- [ ] Update Helm charts and container images
- [ ] Review and update monitoring dashboards
- [ ] Conduct disaster recovery drill
- [ ] Review security scan results
- [ ] Update documentation

## 📞 Emergency Contacts

**Escalation Matrix:**
1. **Level 1**: Self-service using this guide
2. **Level 2**: Homelab administrator (you!)
3. **Level 3**: Community support (K3s Slack, forums)

**Useful Resources:**
- **K3s Documentation**: https://docs.k3s.io/
- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **Prometheus Documentation**: https://prometheus.io/docs/
- **Longhorn Documentation**: https://longhorn.io/docs/

---

**Regular operations keep the cluster healthy and applications running smoothly. When in doubt, check the logs and follow the troubleshooting procedures.** 