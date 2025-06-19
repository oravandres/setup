# K3s etcd Backup & Restore Procedures

## Overview

This document provides step-by-step procedures for restoring a K3s cluster from etcd backups created by the automated backup system. **CRITICAL: Practice these procedures in a test environment before needing them in production.**

## Backup System Architecture

- **Automated Backups**: CronJob runs daily at 2 AM UTC (configurable)
- **Encryption**: All backups are encrypted with GPG using AES256
- **Storage**: Backups stored in MinIO/S3-compatible storage
- **Retention**: Daily backups (7 days), Weekly backups (30 days)
- **Types**: Daily backups Monday-Saturday, Weekly backups on Sunday

## Disaster Recovery Scenarios

### Scenario 1: Single Control Plane Node Failure

**When to use**: One master node has failed but the cluster is still operational.

**Steps**:
1. Verify cluster health: `kubectl get nodes`
2. Replace/repair the failed node hardware
3. Re-install K3s on the replacement node with the same configuration
4. The node will automatically rejoin the cluster
5. Verify: `kubectl get nodes` - all nodes should show "Ready"

**No backup restore needed** - etcd data is replicated across remaining nodes.

### Scenario 2: Majority Control Plane Node Failure

**When to use**: Multiple master nodes have failed and etcd quorum is lost.

**Recovery steps**:
1. Identify one surviving master node (if any)
2. If a master node survives with intact etcd data, use it as the restore base
3. If no master nodes survive intact, proceed to Scenario 3 (Full Cluster Recovery)

### Scenario 3: Complete Cluster Loss / Corruption

**When to use**: All control plane nodes lost or etcd database corrupted.

**This requires full backup restore** - follow the procedures below.

## Pre-Restore Checklist

Before starting any restore procedure:

- [ ] Identify the backup file to restore from
- [ ] Ensure you have access to the MinIO/S3 storage containing backups
- [ ] Have the backup encryption passphrase ready
- [ ] Stop all applications and workloads if possible
- [ ] Document current cluster state if partially functional
- [ ] Prepare fresh master nodes or ensure existing nodes are accessible
- [ ] Have network connectivity to all master nodes
- [ ] Backup current etcd data if any nodes are still functional

## Backup File Selection

### List Available Backups
```bash
# From a node with rclone access
rclone ls minio:/k3s-backups/k3s-etcd-backups/daily/
rclone ls minio:/k3s-backups/k3s-etcd-backups/weekly/

# Via Kubernetes (if cluster partially functional)
kubectl run -i --tty --rm debug --image=rclone/rclone:1.67.0 \
  --restart=Never -- rclone ls minio:/k3s-backups/k3s-etcd-backups/
```

### Backup File Naming Convention
- **Daily**: `snapshot-daily-YYYYMMDDHHMMSS.db.gpg`
- **Weekly**: `snapshot-weekly-YYYYMMDDHHMMSS.db.gpg`

**Choose the backup file closest to your desired restore point.**

## Full Cluster Restore Procedure

### Step 1: Prepare the Restore Environment

1. **Stop K3s on all master nodes**:
   ```bash
   # Run on ALL master nodes
   sudo systemctl stop k3s
   sudo systemctl disable k3s
   ```

2. **Clean etcd data directories** (if corrupted):
   ```bash
   # Run on ALL master nodes - DESTRUCTIVE!
   sudo rm -rf /var/lib/rancher/k3s/server/db/etcd
   ```

3. **Choose primary restore node**: Select one master node as the primary restore target.

### Step 2: Download and Decrypt Backup

On the **primary restore node**:

1. **Download the backup file**:
   ```bash
   # Create restore directory
   sudo mkdir -p /tmp/k3s-restore
   cd /tmp/k3s-restore
   
   # Download backup (replace BACKUP_FILENAME with actual backup)
   rclone copy minio:/k3s-backups/k3s-etcd-backups/daily/BACKUP_FILENAME.db.gpg .
   # OR for weekly backup:
   # rclone copy minio:/k3s-backups/k3s-etcd-backups/weekly/BACKUP_FILENAME.db.gpg .
   ```

2. **Decrypt the backup**:
   ```bash
   # Decrypt using GPG (you'll be prompted for passphrase)
   gpg --decrypt --output restored-snapshot.db BACKUP_FILENAME.db.gpg
   
   # Verify the decrypted file
   ls -la restored-snapshot.db
   file restored-snapshot.db  # Should show SQLite database
   ```

### Step 3: Restore etcd Database

On the **primary restore node only**:

1. **Prepare snapshot location**:
   ```bash
   # Create snapshots directory if it doesn't exist
   sudo mkdir -p /var/lib/rancher/k3s/server/db/snapshots
   
   # Copy restored snapshot to the proper location
   sudo cp restored-snapshot.db /var/lib/rancher/k3s/server/db/snapshots/
   sudo chown root:root /var/lib/rancher/k3s/server/db/snapshots/restored-snapshot.db
   ```

2. **Start K3s with cluster reset**:
   ```bash
   # This will restore from the snapshot and reset cluster membership
   sudo k3s server \
     --cluster-reset \
     --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/restored-snapshot.db
   ```

3. **Monitor the restore process**:
   ```bash
   # Watch logs in another terminal
   sudo journalctl -u k3s -f
   
   # Look for messages like:
   # "Cluster reset complete, now start without --cluster-reset"
   ```

4. **Stop and restart K3s normally**:
   ```bash
   # Once you see "Cluster reset complete" message
   sudo systemctl stop k3s
   
   # Start normally without cluster reset flags
   sudo systemctl start k3s
   sudo systemctl enable k3s
   ```

### Step 4: Verify Primary Node Recovery

On the **primary restore node**:

1. **Check K3s service**:
   ```bash
   sudo systemctl status k3s
   ```

2. **Test kubectl access**:
   ```bash
   # Wait a few minutes for startup
   sudo kubectl get nodes
   sudo kubectl get pods --all-namespaces
   ```

3. **Verify etcd health**:
   ```bash
   sudo kubectl get --raw /healthz/etcd
   ```

**DO NOT proceed to Step 5 until the primary node is fully healthy.**

### Step 5: Add Remaining Master Nodes

For each **additional master node**:

1. **Clean any existing data**:
   ```bash
   sudo rm -rf /var/lib/rancher/k3s/server/db/etcd
   ```

2. **Start K3s normally** (without cluster reset):
   ```bash
   sudo systemctl start k3s
   sudo systemctl enable k3s
   ```

3. **Verify node joins cluster**:
   ```bash
   # On primary node, check nodes
   sudo kubectl get nodes
   
   # Should show all master nodes as Ready
   ```

### Step 6: Restore Worker Nodes

For each **worker node**:

1. **Restart K3s agent**:
   ```bash
   sudo systemctl restart k3s-agent
   ```

2. **Verify worker joins**:
   ```bash
   # On primary node
   sudo kubectl get nodes
   ```

### Step 7: Post-Restore Verification

1. **Check all nodes**:
   ```bash
   kubectl get nodes -o wide
   # All nodes should show "Ready" status
   ```

2. **Verify system pods**:
   ```bash
   kubectl get pods --all-namespaces
   # All system pods should be Running
   ```

3. **Test workload deployment**:
   ```bash
   # Deploy a test pod
   kubectl run test-pod --image=nginx --rm -it --restart=Never -- echo "Cluster restored successfully"
   ```

4. **Verify persistent volumes**:
   ```bash
   kubectl get pv,pvc --all-namespaces
   # PVs should be available, PVCs should be bound
   ```

5. **Check cluster services**:
   ```bash
   kubectl get svc --all-namespaces
   kubectl get ingress --all-namespaces
   ```

## Troubleshooting Common Issues

### Issue: "cluster is not ready to accept members"

**Cause**: etcd cluster hasn't fully initialized on primary node.

**Solution**:
- Wait longer (5-10 minutes) before adding additional nodes
- Check `journalctl -u k3s -f` for completion messages
- Verify primary node etcd is healthy: `kubectl get --raw /healthz/etcd`

### Issue: Restored cluster shows old resource versions

**Cause**: Normal behavior - cluster state restored to backup point.

**Solution**:
- This is expected - you've restored to a point in time
- Re-apply any configurations made after the backup timestamp
- Redeploy applications if needed

### Issue: TLS certificate errors after restore

**Cause**: Time skew or certificate rotation since backup.

**Solution**:
```bash
# Regenerate certificates if needed
sudo k3s certificate rotate-ca
sudo systemctl restart k3s
```

### Issue: Network policies not working

**Cause**: CNI state mismatch after restore.

**Solution**:
```bash
# Restart all pods to refresh CNI state
kubectl delete pods --all --all-namespaces --grace-period=0 --force
```

### Issue: Worker nodes stuck in "NotReady"

**Cause**: Worker agent configuration pointing to old master IPs.

**Solution**:
```bash
# On each worker node, restart the agent
sudo systemctl restart k3s-agent

# If using VIP, ensure VIP is accessible
ping 10.0.0.10  # Your cluster VIP
```

## Testing Restore Procedures

### Regular Restore Testing (Recommended Monthly)

1. **Set up test environment**: Create a separate K3s cluster for testing
2. **Copy production backup**: Download a recent backup file
3. **Practice full restore**: Follow complete restore procedure in test environment
4. **Verify applications**: Deploy test applications and verify functionality
5. **Document any issues**: Update procedures based on findings
6. **Time the process**: Record how long restore takes for planning

### Automated Restore Validation

```bash
# Script to validate backup integrity without full restore
#!/bin/bash
BACKUP_FILE="$1"

# Download and decrypt backup
rclone copy "minio:/k3s-backups/k3s-etcd-backups/daily/$BACKUP_FILE" /tmp/
cd /tmp
gpg --batch --passphrase "$BACKUP_PASSPHRASE" --decrypt "$BACKUP_FILE" > test-restore.db

# Validate SQLite database integrity
sqlite3 test-restore.db "PRAGMA integrity_check;" | grep -q "ok"
if [ $? -eq 0 ]; then
    echo "✅ Backup $BACKUP_FILE integrity verified"
else
    echo "❌ Backup $BACKUP_FILE failed integrity check"
fi

# Cleanup
rm -f test-restore.db "$BACKUP_FILE"
```

## Emergency Contacts and Escalation

When restore procedures fail or additional help is needed:

1. **Check logs**: `journalctl -u k3s -f` on all nodes
2. **Document errors**: Save all error messages and logs
3. **Escalate to team lead**: Contact infrastructure team lead
4. **Engage vendor support**: If using commercial K3s support
5. **Consider alternative recovery**: Manual etcd repair or cluster rebuild

## Security Considerations

- **Backup encryption**: All backups are encrypted - keep passphrase secure
- **Access control**: Limit access to backup storage to authorized personnel only
- **Network security**: Ensure restore procedures work with your network security policies
- **Audit logging**: Log all restore activities for compliance
- **Certificate rotation**: May be needed after restore depending on time elapsed

## Maintenance Tasks

### Weekly
- [ ] Verify automated backups are completing successfully
- [ ] Check backup storage space utilization
- [ ] Review backup retention policy enforcement

### Monthly
- [ ] Test restore procedure in development environment
- [ ] Update restore documentation with any procedural changes
- [ ] Verify encryption keys and access credentials are current

### Quarterly
- [ ] Full disaster recovery drill with stakeholders
- [ ] Review and update emergency contact information
- [ ] Audit backup security and access controls

---

**Remember**: The best disaster recovery plan is one that has been tested regularly. Practice these procedures in a safe environment before you need them in production.

**Last Updated**: Generated by Ansible deployment
**Version**: 1.0
**Contact**: Infrastructure Team 