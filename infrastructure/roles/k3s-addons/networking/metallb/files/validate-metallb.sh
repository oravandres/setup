#!/bin/bash
set -e

echo "🔍 MetalLB LoadBalancer Validation Script"
echo "==========================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check MetalLB namespace and pods
echo "📋 Checking MetalLB deployment status..."

# Check if metallb-system namespace exists
if ! kubectl get namespace metallb-system &> /dev/null; then
    echo "❌ metallb-system namespace not found"
    exit 1
fi

# Check controller pod
CONTROLLER_READY=$(kubectl get pods -n metallb-system -l app.kubernetes.io/component=controller --no-headers | grep -c "Running" || echo "0")
echo "✅ MetalLB Controller pods running: $CONTROLLER_READY"

# Check speaker pods
SPEAKER_READY=$(kubectl get pods -n metallb-system -l app.kubernetes.io/component=speaker --no-headers | grep -c "Running" || echo "0")
echo "✅ MetalLB Speaker pods running: $SPEAKER_READY"

# Check IP Address Pool
echo "📋 Checking IP Address Pool configuration..."
if kubectl get ipaddresspool main-pool -n metallb-system &> /dev/null; then
    POOL_ADDRESSES=$(kubectl get ipaddresspool main-pool -n metallb-system -o jsonpath='{.spec.addresses[*]}')
    echo "✅ IP Address Pool 'main-pool' found with addresses: $POOL_ADDRESSES"
    
    # Verify it's the correct range
    if [[ "$POOL_ADDRESSES" == *"10.0.0.30-10.0.0.50"* ]]; then
        echo "✅ IP range matches requirement: 10.0.0.30-10.0.0.50"
    else
        echo "❌ IP range does not match requirement. Expected: 10.0.0.30-10.0.0.50, Found: $POOL_ADDRESSES"
        exit 1
    fi
else
    echo "❌ IP Address Pool 'main-pool' not found"
    exit 1
fi

# Check L2 Advertisement
echo "📋 Checking L2 Advertisement configuration..."
if kubectl get l2advertisement main-l2adv -n metallb-system &> /dev/null; then
    echo "✅ L2 Advertisement 'main-l2adv' found"
else
    echo "❌ L2 Advertisement 'main-l2adv' not found"
    exit 1
fi

# Test LoadBalancer service
echo "📋 Testing LoadBalancer service..."
if kubectl get svc metallb-test-service &> /dev/null; then
    EXTERNAL_IP=$(kubectl get svc metallb-test-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [[ -n "$EXTERNAL_IP" && "$EXTERNAL_IP" != "null" ]]; then
        echo "✅ Test LoadBalancer service has external IP: $EXTERNAL_IP"
        
        # Verify IP is in correct range
        if [[ "$EXTERNAL_IP" =~ ^10\.0\.0\.([0-9]+)$ ]]; then
            IP_OCTET=${BASH_REMATCH[1]}
            if (( IP_OCTET >= 30 && IP_OCTET <= 50 )); then
                echo "✅ External IP is within expected range (10.0.0.30-10.0.0.50)"
            else
                echo "❌ External IP is outside expected range"
                exit 1
            fi
        else
            echo "❌ External IP is not in 10.0.0.x format"
            exit 1
        fi
        
        # Test connectivity (optional, requires network access)
        echo "📋 Testing connectivity to LoadBalancer..."
        if timeout 5 curl -s "http://$EXTERNAL_IP" &> /dev/null; then
            echo "✅ LoadBalancer service is accessible via HTTP"
        else
            echo "⚠️  LoadBalancer service is not accessible (this may be expected if not on same network)"
        fi
    else
        echo "❌ Test LoadBalancer service does not have an external IP assigned"
        exit 1
    fi
else
    echo "⚠️  Test LoadBalancer service not found (this is optional)"
fi

echo ""
echo "🎉 MetalLB LoadBalancer validation completed successfully!"
echo "📊 Summary:"
echo "   - Controller pods: $CONTROLLER_READY"
echo "   - Speaker pods: $SPEAKER_READY"
echo "   - IP Pool: 10.0.0.30-10.0.0.50 (21 IPs)"
echo "   - Layer 2 mode configured ✅"
echo ""
echo "📖 Next steps:"
echo "   1. Deploy services with type: LoadBalancer"
echo "   2. Services will automatically receive IPs from 10.0.0.30-10.0.0.50"
echo "   3. Configure Ingress Controller for HTTP/HTTPS traffic" 