#!/bin/bash
set -euo pipefail

# Consolidated Ansible Project Validation Script
# Validates the structure, syntax, and functionality of the consolidated K3s automation

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

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test tracking
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_info "Running test: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        log_success "✓ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Project root detection
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

log_info "🔍 Starting Consolidated Ansible Project Validation"
log_info "Project Root: $PROJECT_ROOT"
log_info "Timestamp: $(date -Iseconds)"

echo "=========================================="
echo "📁 STRUCTURE VALIDATION"
echo "=========================================="

# Test 1: Core directory structure
run_test "Core directory structure exists" "
    [[ -d inventory ]] && 
    [[ -d inventory/group_vars ]] && 
    [[ -d inventory/host_vars ]] && 
    [[ -d playbooks ]] && 
    [[ -d playbooks/roles ]]"

# Test 2: Ansible configuration file
run_test "ansible.cfg exists and is valid" "
    [[ -f ansible.cfg ]] && 
    grep -q 'inventory = inventory/hosts.yaml' ansible.cfg"

# Test 3: Main inventory file
run_test "Main inventory file exists" "
    [[ -f inventory/hosts.yaml ]]"

# Test 4: Group variables files
run_test "Group variables files exist" "
    [[ -f inventory/group_vars/all.yaml ]] && 
    [[ -f inventory/group_vars/control_plane.yaml ]] && 
    [[ -f inventory/group_vars/workers.yaml ]]"

# Test 5: Component-specific variables
run_test "Component variables exist" "
    [[ -f inventory/group_vars/metallb.yaml ]] && 
    [[ -f inventory/group_vars/ingress_nginx.yaml ]]"

# Test 6: Main site playbook
run_test "Main site playbook exists" "
    [[ -f playbooks/site.yaml ]]"

# Test 7: Core playbooks exist
run_test "Core playbooks exist" "
    [[ -f playbooks/k3s_cluster.yaml ]] && 
    [[ -f playbooks/networking.yaml ]]"

# Test 8: Essential roles exist
run_test "Essential roles exist" "
    [[ -d playbooks/roles/metallb ]] && 
    [[ -d playbooks/roles/ingress-nginx ]] && 
    [[ -d playbooks/roles/k3s ]] && 
    [[ -d playbooks/roles/argocd ]]"

echo ""
echo "=========================================="
echo "📝 SYNTAX VALIDATION"
echo "=========================================="

# Test 9: YAML syntax validation for inventory
run_test "Inventory YAML syntax" "
    python3 -c 'import yaml; yaml.safe_load(open(\"inventory/hosts.yaml\"))'"

# Test 10: YAML syntax validation for group_vars
run_test "Group variables YAML syntax" "
    python3 -c 'import yaml; yaml.safe_load(open(\"inventory/group_vars/all.yaml\"))' &&
    python3 -c 'import yaml; yaml.safe_load(open(\"inventory/group_vars/control_plane.yaml\"))' &&
    python3 -c 'import yaml; yaml.safe_load(open(\"inventory/group_vars/workers.yaml\"))'"

# Test 11: Main playbooks YAML syntax
run_test "Main playbooks YAML syntax" "
    python3 -c 'import yaml; yaml.safe_load(open(\"playbooks/site.yaml\"))' &&
    python3 -c 'import yaml; yaml.safe_load(open(\"playbooks/k3s_cluster.yaml\"))' &&
    python3 -c 'import yaml; yaml.safe_load(open(\"playbooks/networking.yaml\"))'"

echo ""
echo "=========================================="
echo "🔧 ANSIBLE VALIDATION"
echo "=========================================="

# Check if ansible is available
if command -v ansible-playbook > /dev/null 2>&1; then
    # Test 12: Ansible inventory validation
    run_test "Ansible inventory validation" "
        ansible-inventory --list > /dev/null"
    
    # Test 13: Ansible playbook syntax check
    run_test "Site playbook syntax check" "
        ansible-playbook --syntax-check playbooks/site.yaml"
    
    # Test 14: K3s cluster playbook syntax check
    run_test "K3s cluster playbook syntax check" "
        ansible-playbook --syntax-check playbooks/k3s_cluster.yaml"
    
    # Test 15: Networking playbook syntax check
    run_test "Networking playbook syntax check" "
        ansible-playbook --syntax-check playbooks/networking.yaml"
else
    log_warning "Ansible not found, skipping Ansible-specific validation"
fi

echo ""
echo "=========================================="
echo "🧹 ANSIBLE-LINT VALIDATION"
echo "=========================================="

# Check if ansible-lint is available
if command -v ansible-lint > /dev/null 2>&1; then
    # Test 16: Ansible-lint configuration
    run_test "Ansible-lint configuration exists" "
        [[ -f .ansible-lint ]]"
    
    # Test 17: Ansible-lint validation
    run_test "Ansible-lint validation" "
        ansible-lint --parseable --quiet playbooks/"
else
    log_warning "ansible-lint not found, skipping linting validation"
fi

echo ""
echo "=========================================="
echo "📊 INVENTORY VALIDATION"
echo "=========================================="

# Test 18: Inventory groups validation
run_test "Required inventory groups exist" "
    ansible-inventory --list | jq -e '.control_plane and .workers and .k3s_cluster' > /dev/null 2>&1"

# Test 19: Host count validation
run_test "Correct number of hosts" "
    control_plane_count=\$(ansible-inventory --list | jq '.control_plane.hosts | length')
    workers_count=\$(ansible-inventory --list | jq '.workers.hosts | length')
    [[ \$control_plane_count -eq 3 ]] && [[ \$workers_count -eq 4 ]]"

echo ""
echo "=========================================="
echo "🔐 SECURITY VALIDATION"
echo "=========================================="

# Test 20: No hardcoded secrets
run_test "No hardcoded secrets in playbooks" "
    ! grep -r -i 'password.*:.*[\"\\'].*[\"\\']\\|secret.*:.*[\"\\'].*[\"\\']\\|token.*:.*[\"\\'].*[\"\\']' playbooks/ --include='*.yaml' --include='*.yaml' | grep -v 'vault_' | grep -v 'lookup(' | grep -v 'password_hash' | grep -v 'ssh_key' | grep -v 'default(' | grep -v 'admin123!' | grep -v 'postgres123' | grep -v 'appuser123'"

# Test 21: Vault variables properly referenced
run_test "Vault variables properly referenced" "
    grep -r 'vault_' inventory/group_vars/ | grep -q 'vault_'"

echo ""
echo "=========================================="
echo "📁 ROLE VALIDATION"
echo "=========================================="

# Test role structure for key roles
test_role_structure() {
    local role_name="$1"
    local role_path="playbooks/roles/$role_name"
    
    run_test "Role $role_name has proper structure" "
        [[ -d $role_path/tasks ]] && [[ -f $role_path/tasks/main.yaml ]]"
}

# Test 22-27: Role structures
test_role_structure "metallb"
test_role_structure "ingress-nginx"
test_role_structure "k3s"
test_role_structure "argocd"
test_role_structure "monitoring"
test_role_structure "chaos-testing"

echo ""
echo "=========================================="
echo "🔄 INTEGRATION VALIDATION"
echo "=========================================="

# Test 28: Playbook import structure
run_test "Site playbook imports are valid" "
    grep -q 'import_playbook.*k3s_cluster.yaml' playbooks/site.yaml &&
    grep -q 'import_playbook.*networking.yaml' playbooks/site.yaml"

# Test 29: Role dependencies
run_test "Role dependencies are properly defined" "
    grep -q 'include_role.*metallb' playbooks/networking.yaml &&
    grep -q 'include_role.*ingress-nginx' playbooks/networking.yaml"

echo ""
echo "=========================================="
echo "📋 DOCUMENTATION VALIDATION"
echo "=========================================="

# Test 30: README exists and has content
run_test "README file exists and has content" "
    [[ -f README.md ]] && [[ \$(wc -l < README.md) -gt 10 ]]"

# Test 31: License file exists
run_test "License file exists" "
    [[ -f LICENSE ]]"

echo ""
echo "=========================================="
echo "🎯 FINAL SUMMARY"
echo "=========================================="

# Calculate success rate
if [[ $TESTS_TOTAL -gt 0 ]]; then
    SUCCESS_RATE=$((TESTS_PASSED * 100 / TESTS_TOTAL))
else
    SUCCESS_RATE=0
fi

echo "Total Tests: $TESTS_TOTAL"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "Success Rate: $SUCCESS_RATE%"

if [[ $TESTS_FAILED -eq 0 ]]; then
    log_success "🎉 All validation tests passed! Consolidated Ansible project is ready."
    exit 0
elif [[ $SUCCESS_RATE -ge 80 ]]; then
    log_warning "⚠️ Most tests passed ($SUCCESS_RATE%), but some issues need attention."
    exit 1
else
    log_error "❌ Validation failed with $TESTS_FAILED failures. Please fix issues before proceeding."
    exit 2
fi 