#!/bin/bash

# Fix Linting Issues Script
# This script fixes yamllint and markdownlint issues across the infrastructure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to fix trailing spaces and missing newlines in a file
fix_basic_formatting() {
    local file="$1"
    
    if [[ -f "$file" ]]; then
        # Remove trailing whitespace
        sed -i 's/[[:space:]]*$//' "$file"
        
        # Ensure file ends with newline
        if [[ -s "$file" && $(tail -c1 "$file" | wc -l) -eq 0 ]]; then
            echo "" >> "$file"
        fi
    fi
}

# Function to identify and log long lines
identify_long_lines() {
    local file="$1"
    local max_length="$2"
    
    if [[ -f "$file" ]]; then
        local long_lines=$(awk -v max="$max_length" 'length($0) > max {print NR ": " $0}' "$file")
        if [[ -n "$long_lines" ]]; then
            echo "=== Long lines in $file (>${max_length} chars) ===" >> /tmp/long_lines.log
            echo "$long_lines" >> /tmp/long_lines.log
            echo "" >> /tmp/long_lines.log
        fi
    fi
}

print_status "Starting linting fixes for infrastructure project..."

# Phase 1: Fix YAML files in infrastructure/
print_status "Phase 1: Fixing infrastructure YAML files..."

# Clear long lines log
> /tmp/long_lines.log

# Find all YAML files in infrastructure
find infrastructure/ -name "*.yaml" -o -name "*.yml" | while read -r file; do
    print_status "Processing: $file"
    
    # Basic formatting fixes
    fix_basic_formatting "$file"
    
    # Identify long lines (will need manual review)
    identify_long_lines "$file" 120
done

print_success "Phase 1 completed - infrastructure YAML files processed"

# Phase 2: Fix GitOps YAML files and specific indentation issues
print_status "Phase 2: Fixing GitOps YAML files..."

find gitops/ -name "*.yaml" -o -name "*.yml" | while read -r file; do
    print_status "Processing: $file"
    
    # Basic formatting fixes
    fix_basic_formatting "$file"
    
    # Identify long lines
    identify_long_lines "$file" 120
done

# Fix specific indentation issues in ArgoCD ApplicationSet files
print_status "Fixing ArgoCD ApplicationSet indentation..."

# Fix infrastructure-appset.yaml
if [[ -f "gitops/argocd/infrastructure-appset.yaml" ]]; then
    cat > gitops/argocd/infrastructure-appset.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: infrastructure
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: "{{.values.environment}}"
  template:
    metadata:
      name: 'infrastructure-{{.name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/k3s-homelab-setup
        targetRevision: HEAD
        path: 'gitops/infrastructure/charts'
        helm:
          valueFiles:
            - '../../environments/{{.values.environment}}/values.yaml'
      destination:
        server: '{{.server}}'
        namespace: kube-system
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
EOF
    print_success "Fixed infrastructure-appset.yaml"
fi

# Fix applications-appset.yaml
if [[ -f "gitops/argocd/applications-appset.yaml" ]]; then
    cat > gitops/argocd/applications-appset.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: applications
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: "{{.values.environment}}"
  template:
    metadata:
      name: 'applications-{{.name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/k3s-homelab-setup
        targetRevision: HEAD
        path: 'gitops/applications'
        helm:
          valueFiles:
            - '../environments/{{.values.environment}}/values.yaml'
      destination:
        server: '{{.server}}'
        namespace: default
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
EOF
    print_success "Fixed applications-appset.yaml"
fi

print_success "Phase 2 completed - GitOps YAML files processed"

# Phase 3: Fix Markdown files
print_status "Phase 3: Fixing Markdown files..."

find docs/ -name "*.md" | while read -r file; do
    print_status "Processing: $file"
    
    # Basic formatting fixes
    fix_basic_formatting "$file"
    
    # Identify long lines
    identify_long_lines "$file" 120
done

# Also fix README.md files in root
for readme in README.md; do
    if [[ -f "$readme" ]]; then
        print_status "Processing: $readme"
        fix_basic_formatting "$readme"
        identify_long_lines "$readme" 120
    fi
done

print_success "Phase 3 completed - Markdown files processed"

# Phase 4: Apply basic markdown formatting fixes
print_status "Phase 4: Applying basic markdown formatting fixes..."

# Function to fix common markdown issues
fix_markdown_formatting() {
    local file="$1"
    
    if [[ -f "$file" ]]; then
        # Create a temporary file for processing
        local temp_file=$(mktemp)
        
        # Read the file line by line and apply fixes
        local prev_line=""
        local next_line=""
        local line_num=0
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            ((line_num++))
            
            # Get next line for context
            next_line=$(sed -n "$((line_num + 1))p" "$file")
            
            # Fix headings - ensure blank line before and after
            if [[ "$line" =~ ^#{1,6}[[:space:]] ]]; then
                # Add blank line before heading if previous line is not blank
                if [[ -n "$prev_line" && "$prev_line" != "" ]]; then
                    echo "" >> "$temp_file"
                fi
                echo "$line" >> "$temp_file"
                # Add blank line after heading if next line exists and is not blank
                if [[ -n "$next_line" && "$next_line" != "" && ! "$next_line" =~ ^#{1,6}[[:space:]] ]]; then
                    echo "" >> "$temp_file"
                fi
            # Fix code blocks - ensure blank lines around fenced code blocks
            elif [[ "$line" =~ ^\`\`\` ]]; then
                # Add blank line before code block if previous line is not blank
                if [[ -n "$prev_line" && "$prev_line" != "" ]]; then
                    echo "" >> "$temp_file"
                fi
                echo "$line" >> "$temp_file"
            elif [[ "$line" =~ ^\`\`\`$ ]]; then
                echo "$line" >> "$temp_file"
                # Add blank line after closing code block if next line exists and is not blank
                if [[ -n "$next_line" && "$next_line" != "" ]]; then
                    echo "" >> "$temp_file"
                fi
            else
                echo "$line" >> "$temp_file"
            fi
            
            prev_line="$line"
        done < "$file"
        
        # Replace original file with processed version
        mv "$temp_file" "$file"
    fi
}

# Apply markdown fixes to all markdown files
find docs/ -name "*.md" | while read -r file; do
    print_status "Applying markdown formatting to: $file"
    fix_markdown_formatting "$file"
done

if [[ -f "README.md" ]]; then
    print_status "Applying markdown formatting to: README.md"
    fix_markdown_formatting "README.md"
fi

print_success "Phase 4 completed - Basic markdown formatting applied"

# Summary
print_status "=== SUMMARY ==="
print_success "✅ Fixed trailing spaces in all YAML and Markdown files"
print_success "✅ Ensured all files end with newlines"
print_success "✅ Fixed GitOps ApplicationSet indentation issues"
print_success "✅ Applied basic markdown formatting fixes"

if [[ -s /tmp/long_lines.log ]]; then
    print_warning "⚠️  Some lines exceed the 120-character limit and need manual review:"
    print_warning "   Check /tmp/long_lines.log for details"
    
    # Count files with long lines
    long_line_files=$(grep "^===" /tmp/long_lines.log | wc -l)
    print_warning "   Files with long lines: $long_line_files"
fi

print_status "Next steps:"
echo "1. Review long lines in /tmp/long_lines.log and manually shorten them"
echo "2. Run the linters again to verify fixes:"
echo "   yamllint infrastructure/ gitops/"
echo "   markdownlint docs/ *.md"
echo "   ansible-lint infrastructure/"
echo "3. Commit the changes"

print_success "Linting fixes completed!" 