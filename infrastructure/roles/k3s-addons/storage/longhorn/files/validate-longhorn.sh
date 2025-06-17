#!/bin/bash
set -e

echo "🔍 Longhorn v1.7 Distributed Storage Validation Script"
echo "===================================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

echo "📋 Checking Longhorn deployment status..."

# Check if longhorn-system namespace exists
if ! kubectl get namespace longhorn-system &> /dev/null; then
    echo "❌ longhorn-system namespace not found"
    exit 1
fi

# Check Longhorn Manager pods
MANAGER_READY=$(kubectl get pods -n longhorn-system -l app=longhorn-manager --no-headers | grep -c "Running" || echo "0")
echo "✅ Longhorn Manager pods running: $MANAGER_READY"

# Check Longhorn UI pods
UI_READY=$(kubectl get pods -n longhorn-system -l app=longhorn-ui --no-headers | grep -c "Running" || echo "0")
echo "✅ Longhorn UI pods running: $UI_READY"

# Check Longhorn Engine Image DaemonSet
ENGINE_READY=$(kubectl get pods -n longhorn-system -l app=longhorn-engine-image --no-headers | grep -c "Running" || echo "0")
echo "✅ Longhorn Engine Image pods running: $ENGINE_READY"

# Check Longhorn CSI Driver pods
CSI_DRIVER_READY=$(kubectl get pods -n longhorn-system -l app=csi-attacher --no-headers | grep -c "Running" || echo "0")
CSI_PROVISIONER_READY=$(kubectl get pods -n longhorn-system -l app=csi-provisioner --no-headers | grep -c "Running" || echo "0")
CSI_RESIZER_READY=$(kubectl get pods -n longhorn-system -l app=csi-resizer --no-headers | grep -c "Running" || echo "0")
CSI_SNAPSHOTTER_READY=$(kubectl get pods -n longhorn-system -l app=csi-snapshotter --no-headers | grep -c "Running" || echo "0")

echo "✅ CSI Driver components:"
echo "  - Attacher: $CSI_DRIVER_READY"
echo "  - Provisioner: $CSI_PROVISIONER_READY"
echo "  - Resizer: $CSI_RESIZER_READY"
echo "  - Snapshotter: $CSI_SNAPSHOTTER_READY"

# Check Storage Class
echo ""
echo "📊 Checking Storage Class configuration..."
if kubectl get storageclass longhorn &> /dev/null; then
    echo "✅ Longhorn StorageClass exists"
    
    # Check if it's the default StorageClass
    IS_DEFAULT=$(kubectl get storageclass longhorn -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' || echo "false")
    if [ "$IS_DEFAULT" = "true" ]; then
        echo "✅ Longhorn is the default StorageClass"
    else
        echo "⚠️  Longhorn is not the default StorageClass"
    fi
    
    # Check replica count from StorageClass parameters
    REPLICA_COUNT=$(kubectl get storageclass longhorn -o jsonpath='{.parameters.numberOfReplicas}' || echo "not-set")
    echo "📋 StorageClass replica configuration: $REPLICA_COUNT"
else
    echo "❌ Longhorn StorageClass not found"
    exit 1
fi

# Check Longhorn nodes and disk status
echo ""
echo "🔧 Checking Longhorn nodes and storage..."
NODE_COUNT=$(kubectl get nodes.longhorn.io -n longhorn-system --no-headers | wc -l || echo "0")
echo "✅ Longhorn nodes configured: $NODE_COUNT"

if [ $NODE_COUNT -gt 0 ]; then
    echo "📋 Node status:"
    kubectl get nodes.longhorn.io -n longhorn-system -o custom-columns="NAME:.metadata.name,READY:.status.conditions[?(@.type=='Ready')].status,SCHEDULABLE:.spec.allowScheduling" --no-headers | while read line; do
        echo "  - $line"
    done
fi

# Check for NVMe disks
echo ""
echo "💾 NVMe Storage Detection..."
if kubectl get disks.longhorn.io -n longhorn-system &> /dev/null; then
    NVME_DISKS=$(kubectl get disks.longhorn.io -n longhorn-system -o json | jq -r '.items[] | select(.metadata.name | contains("nvme")) | .metadata.name' | wc -l || echo "0")
    if [ $NVME_DISKS -gt 0 ]; then
        echo "✅ NVMe disks detected: $NVME_DISKS"
        kubectl get disks.longhorn.io -n longhorn-system -o json | jq -r '.items[] | select(.metadata.name | contains("nvme")) | "  - " + .metadata.name + " (" + (.spec.storageReserved | tostring) + "/" + (.status.storageAvailable | tostring) + " bytes)"'
    else
        echo "⚠️  No NVMe disks found. Consider adding NVMe storage for optimal performance."
        echo "💡 To add NVMe disks:"
        echo "   1. Access Longhorn UI"
        echo "   2. Go to Node -> [Select Node] -> Edit Disks"
        echo "   3. Add NVMe mount path (e.g., /mnt/nvme)"
        echo "   4. Tag disk with 'nvme' for identification"
    fi
else
    echo "⚠️  Unable to check disk status. Longhorn may still be initializing."
fi

# Test volume creation with 3 replicas
echo ""
echo "🧪 Testing volume creation with 3 replicas..."

# Create test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: longhorn
EOF

# Wait for PVC to be bound
echo "⏳ Waiting for test PVC to be bound..."
for i in {1..30}; do
    PVC_STATUS=$(kubectl get pvc longhorn-test-pvc -o jsonpath='{.status.phase}' || echo "Unknown")
    if [ "$PVC_STATUS" = "Bound" ]; then
        echo "✅ Test PVC successfully bound"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Test PVC failed to bind within timeout"
        kubectl describe pvc longhorn-test-pvc
        exit 1
    fi
    sleep 2
done

# Check volume replica count
PV_NAME=$(kubectl get pvc longhorn-test-pvc -o jsonpath='{.spec.volumeName}')
if [ -n "$PV_NAME" ]; then
    REPLICA_COUNT=$(kubectl get volumes.longhorn.io -n longhorn-system "$PV_NAME" -o jsonpath='{.spec.numberOfReplicas}' 2>/dev/null || echo "unknown")
    if [ "$REPLICA_COUNT" = "3" ]; then
        echo "✅ Volume created with 3 replicas as required"
    else
        echo "⚠️  Volume replica count: $REPLICA_COUNT (expected: 3)"
    fi
    
    # Check replica distribution
    REPLICA_STATUS=$(kubectl get volumes.longhorn.io -n longhorn-system "$PV_NAME" -o jsonpath='{.status.state}' 2>/dev/null || echo "unknown")
    echo "📊 Volume status: $REPLICA_STATUS"
    
    # Show replica locations
    kubectl get replicas.longhorn.io -n longhorn-system -l "longhornvolume=$PV_NAME" -o custom-columns="NAME:.metadata.name,NODE:.spec.nodeID,STATE:.status.currentState" --no-headers 2>/dev/null | while read line; do
        echo "  - Replica: $line"
    done
fi

# Clean up test PVC
echo ""
echo "🧹 Cleaning up test resources..."
kubectl delete pvc longhorn-test-pvc --ignore-not-found=true

# Check for Longhorn UI access
echo ""
echo "🌐 Checking UI access..."
UI_SERVICE=$(kubectl get svc -n longhorn-system longhorn-frontend-nodeport -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
if [ -n "$UI_SERVICE" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    echo "✅ Longhorn UI available at: http://$NODE_IP:$UI_SERVICE"
else
    echo "⚠️  Longhorn UI NodePort service not found"
fi

# Check backup settings
echo ""
echo "💾 Backup configuration status..."
BACKUP_TARGET=$(kubectl get settings.longhorn.io -n longhorn-system backup-target -o jsonpath='{.value}' 2>/dev/null || echo "")
if [ -n "$BACKUP_TARGET" ] && [ "$BACKUP_TARGET" != "" ]; then
    echo "✅ Backup target configured: $BACKUP_TARGET"
else
    echo "⚠️  No backup target configured. Consider setting up S3/NFS backup for production."
fi

# Performance recommendations
echo ""
echo "🚀 Performance Optimization Recommendations:"
echo "1. 🔧 Configure NVMe storage pools for high-performance workloads"
echo "2. 📊 Monitor disk I/O and adjust replica placement if needed"
echo "3. 💾 Set up backup targets for disaster recovery"
echo "4. 📈 Use Prometheus metrics for performance monitoring"
echo "5. 🏷️  Tag nodes and disks for workload-specific placement"

# Summary
echo ""
echo "==============================================="
if [ $MANAGER_READY -gt 0 ] && [ $UI_READY -gt 0 ] && [ "$PVC_STATUS" = "Bound" ] && [ "$REPLICA_COUNT" = "3" ]; then
    echo "✅ Longhorn v1.7 validation PASSED!"
    echo "✅ 3-replica configuration verified"
    echo "✅ Storage provisioning functional"
    exit 0
else
    echo "❌ Longhorn validation FAILED!"
    echo "Please check the issues above and retry."
    exit 1
fi 