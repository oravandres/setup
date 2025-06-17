# Runbook: Backup and Restore Procedures

## Overview
This runbook covers comprehensive backup and restore procedures for our K3s cluster, including etcd snapshots, Longhorn volumes, and application data.

## Prerequisites
- Root or sudo access to K3s nodes
- kubectl access with cluster-admin privileges
- Access to backup storage locations
- Longhorn UI access for volume backups

## 🗂️ Backup Procedures

### Manual etcd Backup

#### Step 1: Connect to Control Plane Node
```bash
# SSH to the control plane node
ssh user@control-plane-node

# Switch to root (required for etcd operations)
sudo su -
```

**Expected Result**: You should have root access on the control plane node.

#### Step 2: Create etcd Snapshot
```bash
# Create snapshot with timestamp
SNAPSHOT_NAME="manual-backup-$(date +%Y%m%d-%H%M%S)"
k3s etcd-snapshot save --name "$SNAPSHOT_NAME"

# Verify snapshot creation
k3s etcd-snapshot ls | grep "$SNAPSHOT_NAME"
```

**Expected Result**: Snapshot should be listed in the output.
**Troubleshooting**: If command fails, check K3s service status with `systemctl status k3s`.

#### Step 3: Copy Snapshot to Safe Location
```bash
# Default snapshot location
SNAPSHOT_PATH="/var/lib/rancher/k3s/server/db/snapshots/$SNAPSHOT_NAME"

# Copy to backup storage
scp "$SNAPSHOT_PATH" backup-server:/backups/etcd/
# OR copy to S3
aws s3 cp "$SNAPSHOT_PATH" s3://your-backup-bucket/etcd/
```

**Expected Result**: Snapshot should be copied to backup storage.

### Longhorn Volume Backup

#### Step 1: Access Longhorn UI
```bash
# Port forward to Longhorn UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

Open browser to `http://localhost:8080`

#### Step 2: Create Volume Backup via UI
1. Navigate to **Volume** page
2. Select the volume to backup
3. Click **Create Backup**
4. Wait for backup completion

#### Step 3: Create Backup via CLI (Alternative)
```bash
# List available volumes
kubectl get pv

# Create backup for specific volume
kubectl apply -f - <<EOF
apiVersion: longhorn.io/v1beta1
kind: Backup
metadata:
  name: backup-$(date +%Y%m%d-%H%M%S)
  namespace: longhorn-system
spec:
  snapshotName: your-snapshot-name
  labels:
    backup-type: "manual"
    date: "$(date +%Y%m%d)"
EOF
```

**Expected Result**: Backup should appear in Longhorn UI under **Backup** page.

### Application Data Backup

#### Step 1: Database Backup (PostgreSQL Example)
```bash
# Create database backup
kubectl exec -n app-namespace deployment/postgres -- \
  pg_dump -U username dbname | gzip > postgres-backup-$(date +%Y%m%d).sql.gz

# Copy to persistent storage or external location
kubectl cp postgres-backup-$(date +%Y%m%d).sql.gz backup-pod:/backups/
```

#### Step 2: File System Backup
```bash
# Backup application files
kubectl exec -n app-namespace deployment/app -- \
  tar czf - /app/data | gzip > app-data-backup-$(date +%Y%m%d).tar.gz
```

**Expected Result**: Application data should be backed up and stored safely.

## 🔄 Restore Procedures

### Full Cluster Restore from etcd Snapshot

⚠️ **WARNING**: This procedure will restore the entire cluster state. All changes made after the snapshot will be lost.

#### Step 1: Stop K3s on All Nodes
```bash
# On all nodes (control plane and workers)
sudo systemctl stop k3s
# OR for worker nodes
sudo systemctl stop k3s-agent
```

#### Step 2: Restore etcd Snapshot on Control Plane
```bash
# On the primary control plane node
sudo su -

# List available snapshots
k3s etcd-snapshot ls

# Restore from specific snapshot
SNAPSHOT_NAME="manual-backup-20240117-143000"
k3s etcd-snapshot restore --name "$SNAPSHOT_NAME"
```

**Expected Result**: Command should complete without errors.
**Troubleshooting**: If restore fails, check snapshot integrity and permissions.

#### Step 3: Start K3s Services
```bash
# Start control plane first
sudo systemctl start k3s

# Wait for control plane to be ready
kubectl get nodes

# Start worker nodes
# (On each worker node)
sudo systemctl start k3s-agent
```

#### Step 4: Verify Cluster State
```bash
# Check all nodes are ready
kubectl get nodes

# Check pod status
kubectl get pods --all-namespaces

# Verify ArgoCD applications
kubectl get applications -n argocd
```

**Expected Result**: Cluster should be restored to the snapshot state.

### Longhorn Volume Restore

#### Step 1: Access Longhorn UI
```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

#### Step 2: Restore Volume
1. Navigate to **Backup** page in Longhorn UI
2. Select the backup to restore
3. Click **Restore**
4. Choose restore location (new volume or existing)
5. Wait for restoration to complete

#### Step 3: Update Application to Use Restored Volume
```bash
# If restored to new volume, update PVC
kubectl patch pvc app-data-pvc -n app-namespace -p '{"spec":{"volumeName":"new-volume-name"}}'

# Restart application to mount new volume
kubectl rollout restart deployment/app -n app-namespace
```

### Application Data Restore

#### Step 1: Database Restore (PostgreSQL Example)
```bash
# Copy backup to pod
kubectl cp postgres-backup-20240117.sql.gz app-namespace/postgres-pod:/tmp/

# Restore database
kubectl exec -n app-namespace deployment/postgres -- \
  psql -U username -d dbname -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

kubectl exec -n app-namespace deployment/postgres -- \
  gunzip -c /tmp/postgres-backup-20240117.sql.gz | psql -U username -d dbname
```

#### Step 2: File System Restore
```bash
# Copy backup to pod
kubectl cp app-data-backup-20240117.tar.gz app-namespace/app-pod:/tmp/

# Restore files
kubectl exec -n app-namespace deployment/app -- \
  tar xzf /tmp/app-data-backup-20240117.tar.gz -C /

# Restart application
kubectl rollout restart deployment/app -n app-namespace
```

## 🔍 Backup Verification

### Verify etcd Snapshot Integrity
```bash
# Check snapshot details
k3s etcd-snapshot ls --name snapshot-name

# Test restore in development environment
# (Perform test restore on dev cluster)
```

### Verify Longhorn Backup
```bash
# Check backup status via CLI
kubectl get backups -n longhorn-system

# Verify backup in Longhorn UI
# Navigate to Backup page and check status
```

### Test Application Data Restore
```bash
# Periodically test restore procedures in development
# Document any issues or improvements needed
```

## 🚨 Emergency Restore Scenarios

### Scenario 1: Single Node Failure
```bash
# K3s automatically handles single node failures
# Verify cluster is healthy
kubectl get nodes

# If node is permanently lost, remove from cluster
kubectl delete node failed-node-name

# Add replacement node using Ansible
ansible-playbook -i inventory/production/hosts.yml playbooks/add-node.yml
```

### Scenario 2: Control Plane Corruption
```bash
# Restore from latest etcd snapshot
# Follow full cluster restore procedure above

# If multiple control plane nodes exist, other nodes may remain healthy
kubectl get nodes
```

### Scenario 3: Complete Data Loss
```bash
# 1. Rebuild cluster infrastructure with Ansible
cd infrastructure/
ansible-playbook -i inventory/production/hosts.yml playbooks/site.yml

# 2. Restore etcd snapshot
# Follow etcd restore procedure above

# 3. Verify all applications are restored
kubectl get applications -n argocd
argocd app sync --all
```

## 📊 Backup Monitoring

### Check Backup Status
```bash
# Check etcd snapshots
k3s etcd-snapshot ls | tail -10

# Check Longhorn backups
kubectl get backups -n longhorn-system

# Monitor backup storage usage
df -h /var/lib/rancher/k3s/server/db/snapshots/
```

### Automated Backup Verification
```bash
# Create script to verify daily backups
cat << 'EOF' > /usr/local/bin/verify-backups.sh
#!/bin/bash
# Check if today's etcd backup exists
TODAY=$(date +%Y%m%d)
if k3s etcd-snapshot ls | grep -q "$TODAY"; then
    echo "✅ Today's etcd backup found"
else
    echo "❌ Missing today's etcd backup"
    exit 1
fi

# Check Longhorn backup status
FAILED_BACKUPS=$(kubectl get backups -n longhorn-system --no-headers | grep -c Error)
if [ "$FAILED_BACKUPS" -eq 0 ]; then
    echo "✅ All Longhorn backups successful"
else
    echo "❌ $FAILED_BACKUPS failed Longhorn backups"
    exit 1
fi
EOF

chmod +x /usr/local/bin/verify-backups.sh

# Add to cron for daily verification
echo "0 8 * * * /usr/local/bin/verify-backups.sh" | crontab -
```

## 📝 Backup Schedule Recommendations

### Automated Backup Schedule
- **etcd snapshots**: Every 6 hours
- **Longhorn volumes**: Daily for critical data, weekly for others
- **Application data**: Based on change frequency and RTO requirements

### Retention Policy
- **etcd snapshots**: Keep 7 daily, 4 weekly, 12 monthly
- **Longhorn backups**: Keep 7 daily, 4 weekly, 12 monthly
- **Application backups**: Based on compliance requirements

## 🔧 Troubleshooting

### Common Issues

#### etcd Snapshot Fails
```bash
# Check K3s service status
systemctl status k3s

# Check disk space
df -h /var/lib/rancher/k3s/server/db/snapshots/

# Check etcd cluster health
kubectl get nodes
```

#### Longhorn Backup Fails
```bash
# Check Longhorn system status
kubectl get pods -n longhorn-system

# Check backup target configuration
kubectl get backuptargets -n longhorn-system -o yaml

# Review Longhorn logs
kubectl logs -n longhorn-system -l app=longhorn-manager
```

#### Restore Fails
```bash
# Verify snapshot integrity
k3s etcd-snapshot ls --name snapshot-name

# Check available disk space
df -h

# Review K3s logs
journalctl -u k3s -f
```

---

*Always test backup and restore procedures in development environments before relying on them for production recovery.* 