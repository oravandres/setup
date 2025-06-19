#!/bin/bash
set -e

echo "🔍 Ingress-NGINX Controller Validation Script"
echo "=============================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check Ingress-NGINX namespace and pods
echo "📋 Checking Ingress-NGINX deployment status..."

# Check if ingress-nginx namespace exists
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    echo "❌ ingress-nginx namespace not found"
    exit 1
fi

# Check controller pods (should be DaemonSet)
CONTROLLER_PODS=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller --no-headers 2>/dev/null || echo "")
if [[ -z "$CONTROLLER_PODS" ]]; then
    echo "❌ No Ingress-NGINX controller pods found"
    exit 1
fi

RUNNING_CONTROLLERS=$(echo "$CONTROLLER_PODS" | grep -c "Running" || echo "0")
TOTAL_CONTROLLERS=$(echo "$CONTROLLER_PODS" | wc -l)
echo "✅ Ingress-NGINX Controller pods: $RUNNING_CONTROLLERS/$TOTAL_CONTROLLERS Running"

# Verify DaemonSet deployment
DAEMONSET_INFO=$(kubectl get daemonset -n ingress-nginx ingress-nginx-controller 2>/dev/null || echo "")
if [[ -n "$DAEMONSET_INFO" ]]; then
    echo "✅ Deployed as DaemonSet ✓"
    DESIRED=$(echo "$DAEMONSET_INFO" | tail -1 | awk '{print $2}')
    READY=$(echo "$DAEMONSET_INFO" | tail -1 | awk '{print $4}')
    echo "   - Desired/Ready: $READY/$DESIRED"
else
    echo "❌ Not deployed as DaemonSet (should be DaemonSet, not Deployment)"
    # Check if it's deployed as Deployment instead
    if kubectl get deployment -n ingress-nginx ingress-nginx-controller &> /dev/null; then
        echo "   - Found Deployment instead of DaemonSet"
    fi
fi

# Check hostNetwork configuration
echo "📋 Checking hostNetwork configuration..."
HOST_NETWORK=$(kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].spec.hostNetwork}' 2>/dev/null || echo "false")
if [[ "$HOST_NETWORK" == "true" ]]; then
    echo "✅ hostNetwork enabled ✓"
else
    echo "❌ hostNetwork not enabled (required for MetalLB Layer 2 integration)"
fi

# Check LoadBalancer service and IP assignment
echo "📋 Checking LoadBalancer service..."
if kubectl get svc ingress-nginx-controller -n ingress-nginx &> /dev/null; then
    EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [[ -n "$EXTERNAL_IP" && "$EXTERNAL_IP" != "null" ]]; then
        echo "✅ LoadBalancer service has external IP: $EXTERNAL_IP"
        
        # Verify IP is in MetalLB range (10.0.0.30-50)
        if [[ "$EXTERNAL_IP" =~ ^10\.0\.0\.([0-9]+)$ ]]; then
            IP_OCTET=${BASH_REMATCH[1]}
            if (( IP_OCTET >= 30 && IP_OCTET <= 50 )); then
                echo "✅ External IP is within MetalLB range (10.0.0.30-10.0.0.50)"
            else
                echo "❌ External IP is outside MetalLB range"
                exit 1
            fi
        else
            echo "❌ External IP is not in expected 10.0.0.x format"
            exit 1
        fi
    else
        echo "❌ LoadBalancer service does not have an external IP assigned"
        exit 1
    fi
else
    echo "❌ Ingress-NGINX controller service not found"
    exit 1
fi

# Check default ingress class
echo "📋 Checking default ingress class..."
DEFAULT_CLASS=$(kubectl get ingressclass nginx -o jsonpath='{.metadata.annotations.ingressclass\.kubernetes\.io/is-default-class}' 2>/dev/null || echo "false")
if [[ "$DEFAULT_CLASS" == "true" ]]; then
    echo "✅ nginx set as default ingress class ✓"
else
    echo "⚠️  nginx not set as default ingress class"
fi

# Test basic connectivity
echo "📋 Testing basic HTTP connectivity..."
if timeout 10 curl -s "http://$EXTERNAL_IP" &> /dev/null; then
    echo "✅ Basic HTTP connectivity working"
    
    # Test ModSecurity WAF
    echo "📋 Testing ModSecurity WAF blocking..."
    WAF_RESPONSE=$(timeout 10 curl -s -w "%{http_code}" -o /dev/null "http://$EXTERNAL_IP/?id=<script>alert('xss')</script>" 2>/dev/null || echo "000")
    
    if [[ "$WAF_RESPONSE" == "403" || "$WAF_RESPONSE" == "406" ]]; then
        echo "✅ ModSecurity WAF is blocking malicious requests (HTTP $WAF_RESPONSE)"
    elif [[ "$WAF_RESPONSE" == "200" ]]; then
        echo "❌ ModSecurity WAF may not be working - malicious request was allowed"
    else
        echo "⚠️  ModSecurity test inconclusive (HTTP $WAF_RESPONSE)"
    fi
else
    echo "⚠️  Basic HTTP connectivity failed (this may be expected if not on same network)"
fi

# Check if test application is deployed
echo "📋 Checking test application..."
if kubectl get deployment test-webapp &> /dev/null; then
    TEST_PODS=$(kubectl get pods -l app=test-webapp --no-headers | grep -c "Running" || echo "0")
    echo "✅ Test application deployed: $TEST_PODS pods running"
    
    if kubectl get ingress test-webapp-ingress &> /dev/null; then
        echo "✅ Test ingress resource found"
    else
        echo "⚠️  Test ingress resource not found"
    fi
else
    echo "⚠️  Test application not deployed"
fi

# Check configuration details
echo "📋 Checking advanced configuration..."

# Check for ModSecurity configuration
MODSEC_CONFIG=$(kubectl get configmap -n ingress-nginx ingress-nginx-controller -o jsonpath='{.data.enable-modsecurity}' 2>/dev/null || echo "false")
if [[ "$MODSEC_CONFIG" == "true" ]]; then
    echo "✅ ModSecurity enabled in configuration"
else
    echo "⚠️  ModSecurity not explicitly enabled in ConfigMap"
fi

# Check OWASP CRS
OWASP_CONFIG=$(kubectl get configmap -n ingress-nginx ingress-nginx-controller -o jsonpath='{.data.enable-owasp-modsecurity-crs}' 2>/dev/null || echo "false")
if [[ "$OWASP_CONFIG" == "true" ]]; then
    echo "✅ OWASP Core Rule Set enabled"
else
    echo "⚠️  OWASP CRS not explicitly enabled in ConfigMap"
fi

echo ""
echo "🎉 Ingress-NGINX Controller validation summary:"
echo "📊 Status:"
echo "   - Controller pods: $RUNNING_CONTROLLERS/$TOTAL_CONTROLLERS"
echo "   - External IP: $EXTERNAL_IP"
echo "   - DaemonSet: $([[ -n "$DAEMONSET_INFO" ]] && echo "Yes" || echo "No")"
echo "   - hostNetwork: $HOST_NETWORK"
echo "   - Default class: $DEFAULT_CLASS"
echo "   - ModSecurity: $([[ "$MODSEC_CONFIG" == "true" ]] && echo "Enabled" || echo "Check required")"
echo ""
echo "📖 Next steps:"
echo "   1. Configure DNS or /etc/hosts for your domains"
echo "   2. Deploy applications with Ingress resources"
echo "   3. Configure TLS certificates (Task 7)"
echo "   4. Monitor WAF logs for security events" 