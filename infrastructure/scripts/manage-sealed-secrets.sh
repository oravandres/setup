#!/bin/bash
# Sealed Secrets Management Script for K3s Infrastructure
# This script helps manage sealed secrets across different environments

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
SEALED_SECRETS_NS="kube-system"
GITOPS_SECRETS_DIR="$PROJECT_ROOT/gitops/secrets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_deps=()
    
    if ! command_exists kubectl; then
        missing_deps+=("kubectl")
    fi
    
    if ! command_exists kubeseal; then
        missing_deps+=("kubeseal")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install them first:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                kubectl)
                    echo "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
                    ;;
                kubeseal)
                    echo "  - kubeseal: https://github.com/bitnami-labs/sealed-secrets#installation"
                    ;;
            esac
        done
        exit 1
    fi
    
    if [[ ! -f "$KUBECONFIG" ]]; then
        log_error "Kubeconfig not found at $KUBECONFIG"
        log_info "Please ensure your cluster is running and KUBECONFIG is set correctly"
        exit 1
    fi
    
    # Check if sealed-secrets controller is running
    if ! kubectl --kubeconfig="$KUBECONFIG" get pods -n "$SEALED_SECRETS_NS" -l name=sealed-secrets-controller >/dev/null 2>&1; then
        log_error "Sealed Secrets controller not found in namespace $SEALED_SECRETS_NS"
        log_info "Please deploy the sealed-secrets controller first"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Get public key from cluster
get_public_key() {
    local output_file="${1:-/tmp/sealed-secrets-public.pem}"
    
    log_info "Fetching public key from cluster..."
    
    if kubectl --kubeconfig="$KUBECONFIG" get secret -n "$SEALED_SECRETS_NS" \
        -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
        -o jsonpath='{.items[0].data.tls\.crt}' | base64 -d > "$output_file"; then
        log_success "Public key saved to $output_file"
        return 0
    else
        log_error "Failed to fetch public key"
        return 1
    fi
}

# Validate environment
validate_environment() {
    local env="$1"
    case "$env" in
        dev|staging|production|shared)
            return 0
            ;;
        *)
            log_error "Invalid environment: $env"
            log_info "Valid environments: dev, staging, production, shared"
            return 1
            ;;
    esac
}

# Create sealed secret interactively
create_sealed_secret() {
    local secret_name="$1"
    local namespace="$2"
    local environment="$3"
    local secret_type="${4:-generic}"
    
    if ! validate_environment "$environment"; then
        return 1
    fi
    
    log_info "Creating sealed secret: $secret_name"
    log_info "Environment: $environment"
    log_info "Namespace: $namespace"
    log_info "Type: $secret_type"
    
    # Ensure output directory exists
    local output_dir="$GITOPS_SECRETS_DIR/$environment"
    mkdir -p "$output_dir"
    
    # Create temporary files
    local temp_secret=$(mktemp)
    local public_key="/tmp/sealed-secrets-public.pem"
    local output_file="$output_dir/${secret_name}-sealed-secret.yaml"
    
    # Get public key
    if ! get_public_key "$public_key"; then
        rm -f "$temp_secret"
        return 1
    fi
    
    # Create secret based on type
    case "$secret_type" in
        generic)
            create_generic_secret "$secret_name" "$namespace" "$temp_secret"
            ;;
        tls)
            create_tls_secret "$secret_name" "$namespace" "$temp_secret"
            ;;
        docker-registry)
            create_docker_registry_secret "$secret_name" "$namespace" "$temp_secret"
            ;;
        *)
            log_error "Unsupported secret type: $secret_type"
            rm -f "$temp_secret"
            return 1
            ;;
    esac
    
    # Seal the secret
    log_info "Sealing secret..."
    if kubeseal --cert "$public_key" --format=yaml < "$temp_secret" > "$output_file"; then
        log_success "Sealed secret created: $output_file"
        
        # Add metadata annotation
        cat >> "$output_file" << EOF
# Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Environment: $environment
# Type: $secret_type
EOF
        
        log_info "Next steps:"
        echo "  1. Review the generated file: $output_file"
        echo "  2. Commit to Git: git add $output_file && git commit -m 'Add $secret_name sealed secret for $environment'"
        echo "  3. Push changes: git push"
        echo "  4. Apply via GitOps or directly: kubectl apply -f $output_file"
    else
        log_error "Failed to seal secret"
        rm -f "$temp_secret"
        return 1
    fi
    
    # Clean up
    rm -f "$temp_secret"
}

# Create generic secret interactively
create_generic_secret() {
    local secret_name="$1"
    local namespace="$2"
    local temp_file="$3"
    
    log_info "Creating generic secret - enter key-value pairs"
    log_info "Press Enter with empty key to finish"
    
    local kubectl_args=()
    
    while true; do
        echo -n "Enter key name (or press Enter to finish): "
        read -r key
        
        if [[ -z "$key" ]]; then
            break
        fi
        
        echo -n "Enter value for '$key' (input hidden): "
        read -rs value
        echo
        
        if [[ -z "$value" ]]; then
            log_warning "Empty value for key '$key', skipping..."
            continue
        fi
        
        kubectl_args+=("--from-literal=$key=$value")
    done
    
    if [[ ${#kubectl_args[@]} -eq 0 ]]; then
        log_error "No key-value pairs provided"
        return 1
    fi
    
    # Create the secret
    kubectl create secret generic "$secret_name" \
        --namespace="$namespace" \
        --dry-run=client -o yaml \
        "${kubectl_args[@]}" > "$temp_file"
}

# Create TLS secret interactively
create_tls_secret() {
    local secret_name="$1"
    local namespace="$2"
    local temp_file="$3"
    
    log_info "Creating TLS secret"
    
    echo -n "Enter path to certificate file: "
    read -r cert_file
    
    echo -n "Enter path to private key file: "
    read -r key_file
    
    if [[ ! -f "$cert_file" ]]; then
        log_error "Certificate file not found: $cert_file"
        return 1
    fi
    
    if [[ ! -f "$key_file" ]]; then
        log_error "Private key file not found: $key_file"
        return 1
    fi
    
    kubectl create secret tls "$secret_name" \
        --namespace="$namespace" \
        --cert="$cert_file" \
        --key="$key_file" \
        --dry-run=client -o yaml > "$temp_file"
}

# Create Docker registry secret interactively
create_docker_registry_secret() {
    local secret_name="$1"
    local namespace="$2"
    local temp_file="$3"
    
    log_info "Creating Docker registry secret"
    
    echo -n "Enter Docker registry server (e.g., https://index.docker.io/v1/): "
    read -r server
    
    echo -n "Enter Docker registry username: "
    read -r username
    
    echo -n "Enter Docker registry password (input hidden): "
    read -rs password
    echo
    
    echo -n "Enter Docker registry email: "
    read -r email
    
    kubectl create secret docker-registry "$secret_name" \
        --namespace="$namespace" \
        --docker-server="$server" \
        --docker-username="$username" \
        --docker-password="$password" \
        --docker-email="$email" \
        --dry-run=client -o yaml > "$temp_file"
}

# List sealed secrets
list_sealed_secrets() {
    local environment="${1:-all}"
    
    log_info "Listing sealed secrets..."
    
    if [[ "$environment" == "all" ]]; then
        echo
        echo "=== All Environments ==="
        for env in dev staging production shared; do
            if [[ -d "$GITOPS_SECRETS_DIR/$env" ]]; then
                echo
                echo "--- $env ---"
                find "$GITOPS_SECRETS_DIR/$env" -name "*.yaml" -type f | while read -r file; do
                    local basename=$(basename "$file")
                    local secret_name=$(grep "name:" "$file" | head -1 | awk '{print $2}')
                    echo "  $basename -> $secret_name"
                done
            fi
        done
    else
        if ! validate_environment "$environment"; then
            return 1
        fi
        
        if [[ ! -d "$GITOPS_SECRETS_DIR/$environment" ]]; then
            log_warning "No secrets directory found for environment: $environment"
            return 0
        fi
        
        echo
        echo "=== $environment Environment ==="
        find "$GITOPS_SECRETS_DIR/$environment" -name "*.yaml" -type f | while read -r file; do
            local basename=$(basename "$file")
            local secret_name=$(grep "name:" "$file" | head -1 | awk '{print $2}')
            echo "  $basename -> $secret_name"
        done
    fi
}

# Status check
status_check() {
    log_info "Checking sealed secrets status..."
    
    # Check controller
    echo
    echo "=== Controller Status ==="
    kubectl --kubeconfig="$KUBECONFIG" get pods -n "$SEALED_SECRETS_NS" -l name=sealed-secrets-controller
    
    # Check sealed secrets in cluster
    echo
    echo "=== Sealed Secrets in Cluster ==="
    kubectl --kubeconfig="$KUBECONFIG" get sealedsecrets -A
    
    # Check regular secrets (created by sealed secrets)
    echo
    echo "=== Regular Secrets (non-system) ==="
    kubectl --kubeconfig="$KUBECONFIG" get secrets -A | grep -v "kubernetes.io" | grep -v "helm.sh" | grep -v "cattle" || true
}

# Validate sealed secret file
validate_secret() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    log_info "Validating sealed secret: $file"
    
    if kubeseal --validate < "$file"; then
        log_success "Sealed secret is valid"
    else
        log_error "Sealed secret validation failed"
        return 1
    fi
}

# Show usage
usage() {
    cat << EOF
Sealed Secrets Management Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    create <name> <namespace> <environment> [type]
                        Create a new sealed secret
                        Types: generic (default), tls, docker-registry
                        Environments: dev, staging, production, shared
                        
    list [environment]  List sealed secrets (all environments if not specified)
    
    status              Show controller and secrets status
    
    validate <file>     Validate a sealed secret file
    
    get-key [file]      Get public key from cluster (default: /tmp/sealed-secrets-public.pem)
    
    check               Check prerequisites
    
    help                Show this help message

Examples:
    $0 create myapp-db-secrets default dev generic
    $0 create wildcard-tls kube-system production tls
    $0 create registry-creds default staging docker-registry
    $0 list dev
    $0 status
    $0 validate gitops/secrets/dev/myapp-sealed-secret.yaml

Environment Variables:
    KUBECONFIG          Path to kubeconfig file (default: /etc/rancher/k3s/k3s.yaml)

EOF
}

# Main execution
main() {
    case "${1:-help}" in
        create)
            if [[ $# -lt 4 || $# -gt 5 ]]; then
                log_error "Usage: $0 create <name> <namespace> <environment> [type]"
                exit 1
            fi
            check_prerequisites
            create_sealed_secret "$2" "$3" "$4" "${5:-generic}"
            ;;
        list)
            list_sealed_secrets "${2:-all}"
            ;;
        status)
            check_prerequisites
            status_check
            ;;
        validate)
            if [[ $# -ne 2 ]]; then
                log_error "Usage: $0 validate <file>"
                exit 1
            fi
            check_prerequisites
            validate_secret "$2"
            ;;
        get-key)
            check_prerequisites
            get_public_key "${2:-/tmp/sealed-secrets-public.pem}"
            ;;
        check)
            check_prerequisites
            ;;
        help|*)
            usage
            ;;
    esac
}

main "$@" 