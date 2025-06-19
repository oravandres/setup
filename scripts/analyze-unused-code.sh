#!/bin/bash

# Project Unused Code and Files Analysis Script
# This script analyzes the repository to identify potentially unused files, code elements, and comments
# WITHOUT making any modifications to the codebase

set -euo pipefail

# Configuration
REPORT_DIR="reports"
REPORT_FILE="$REPORT_DIR/unused-code-analysis-$(date +%Y%m%d-%H%M%S).md"
TEMP_DIR="/tmp/unused-analysis-$$"

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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Create necessary directories
setup_analysis() {
    log_info "Setting up analysis environment..."
    mkdir -p "$REPORT_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Verify we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not in a git repository. Exiting."
        exit 1
    fi
    
    log_success "Analysis environment ready"
}

# Function to analyze unused files
analyze_unused_files() {
    log_info "Analyzing potentially unused files..."
    
    local unused_files="$TEMP_DIR/unused_files.txt"
    local all_files="$TEMP_DIR/all_files.txt"
    local referenced_files="$TEMP_DIR/referenced_files.txt"
    
    # Get all tracked files (excluding .git, .taskmaster, node_modules, etc.)
    find . -type f \
        -not -path "./.git/*" \
        -not -path "./.taskmaster/*" \
        -not -path "./node_modules/*" \
        -not -path "./.venv/*" \
        -not -path "./venv/*" \
        -not -path "./.pytest_cache/*" \
        -not -path "./__pycache__/*" \
        > "$all_files"
    
    # Find files that are referenced in other files
    # This is a heuristic approach - looking for filename references
    touch "$referenced_files"
    
    # Look for file references in various ways
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            filename=$(basename "$file")
            filename_no_ext="${filename%.*}"
            
            # Search for references to this file in other files
            if grep -r -l --exclude-dir=.git --exclude-dir=.taskmaster \
                --exclude-dir=node_modules --exclude-dir=.venv \
                -E "(import|include|source|require|load|from|\.\/|\.\.\/|href|src)" . 2>/dev/null | \
                xargs grep -l "$filename\|$filename_no_ext" 2>/dev/null | \
                grep -v "^$file$" > /dev/null 2>&1; then
                echo "$file" >> "$referenced_files"
            fi
            
            # Check if file is referenced in Ansible playbooks
            if grep -r -l --include="*.yaml" --include="*.yaml" \
                -E "(role:|include:|import_|name:|src:|dest:)" . 2>/dev/null | \
                xargs grep -l "$filename\|$filename_no_ext" 2>/dev/null | \
                grep -v "^$file$" > /dev/null 2>&1; then
                echo "$file" >> "$referenced_files"
            fi
            
            # Check if file is referenced in documentation
            if grep -r -l --include="*.md" "$filename\|$filename_no_ext" . 2>/dev/null | \
                grep -v "^$file$" > /dev/null 2>&1; then
                echo "$file" >> "$referenced_files"
            fi
        fi
    done < "$all_files"
    
    # Find files that are not referenced
    sort "$all_files" > "$all_files.sorted"
    sort "$referenced_files" | uniq > "$referenced_files.sorted"
    comm -23 "$all_files.sorted" "$referenced_files.sorted" > "$unused_files"
    
    # Filter out common files that should not be considered unused
    grep -v -E "\.(md|txt|license|gitignore|gitattributes)$|README|LICENSE|CHANGELOG|\.github/|docs/|\.taskmaster/" "$unused_files" > "$unused_files.filtered" || true
    
    local count=$(wc -l < "$unused_files.filtered" 2>/dev/null || echo "0")
    log_info "Found $count potentially unused files"
    
    # Store results
    cp "$unused_files.filtered" "$TEMP_DIR/final_unused_files.txt" 2>/dev/null || touch "$TEMP_DIR/final_unused_files.txt"
}

# Function to analyze unused variables and functions in shell scripts
analyze_unused_shell_elements() {
    log_info "Analyzing unused elements in shell scripts..."
    
    local unused_shell="$TEMP_DIR/unused_shell_elements.txt"
    echo "# Unused Shell Script Elements" > "$unused_shell"
    
    # Find all shell scripts
    find . -name "*.sh" -not -path "./.git/*" -not -path "./.taskmaster/*" | while IFS= read -r script; do
        if [[ -f "$script" ]]; then
            echo "## Analyzing: $script" >> "$unused_shell"
            
            # Find function definitions
            local functions=$(grep -n "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$script" 2>/dev/null || true)
            
            if [[ -n "$functions" ]]; then
                while IFS= read -r func_line; do
                    local line_num=$(echo "$func_line" | cut -d: -f1)
                    local func_name=$(echo "$func_line" | sed 's/.*\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/')
                    
                    # Check if function is called elsewhere in the file
                    if ! grep -q "$func_name" "$script" --exclude-line="$line_num" 2>/dev/null; then
                        echo "- **Potentially unused function**: \`$func_name\` at line $line_num" >> "$unused_shell"
                    fi
                done <<< "$functions"
            fi
            
            # Find variable assignments that might be unused
            local variables=$(grep -n "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*=" "$script" 2>/dev/null || true)
            
            if [[ -n "$variables" ]]; then
                while IFS= read -r var_line; do
                    local line_num=$(echo "$var_line" | cut -d: -f1)
                    local var_name=$(echo "$var_line" | cut -d= -f1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                    
                    # Check if variable is used elsewhere (basic check)
                    if ! grep -q "\$$var_name\|\${$var_name}" "$script" 2>/dev/null; then
                        echo "- **Potentially unused variable**: \`$var_name\` at line $line_num" >> "$unused_shell"
                    fi
                done <<< "$variables"
            fi
            
            echo "" >> "$unused_shell"
        fi
    done
    
    log_info "Shell script analysis completed"
}

# Function to analyze unused keys in YAML files
analyze_unused_yaml_elements() {
    log_info "Analyzing potentially unused elements in YAML files..."
    
    local unused_yaml="$TEMP_DIR/unused_yaml_elements.txt"
    echo "# Unused YAML Elements" > "$unused_yaml"
    
    # Find YAML files that might have unused keys
    find . \( -name "*.yaml" -o -name "*.yaml" \) -not -path "./.git/*" -not -path "./.taskmaster/*" | while IFS= read -r yaml_file; do
        if [[ -f "$yaml_file" ]]; then
            echo "## Analyzing: $yaml_file" >> "$unused_yaml"
            
            # Look for keys that might be unused (this is heuristic)
            # Check for keys that are defined but not referenced elsewhere
            local keys=$(grep -n "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_-]*:" "$yaml_file" 2>/dev/null || true)
            
            if [[ -n "$keys" ]]; then
                while IFS= read -r key_line; do
                    local line_num=$(echo "$key_line" | cut -d: -f1)
                    local key_name=$(echo "$key_line" | sed 's/.*\([a-zA-Z_][a-zA-Z0-9_-]*\):.*/\1/')
                    
                    # Skip common keys
                    if [[ "$key_name" =~ ^(name|version|description|metadata|spec|data|kind|apiVersion)$ ]]; then
                        continue
                    fi
                    
                    # Check if key is referenced in other files (very basic check)
                    if ! grep -r -q "$key_name" . --exclude="$yaml_file" --exclude-dir=.git --exclude-dir=.taskmaster 2>/dev/null; then
                        echo "- **Potentially unused key**: \`$key_name\` at line $line_num" >> "$unused_yaml"
                    fi
                done <<< "$keys"
            fi
            
            echo "" >> "$unused_yaml"
        fi
    done
    
    log_info "YAML analysis completed"
}

# Function to find potentially obsolete comments
analyze_obsolete_comments() {
    log_info "Analyzing potentially obsolete comments..."
    
    local obsolete_comments="$TEMP_DIR/obsolete_comments.txt"
    echo "# Potentially Obsolete Comments" > "$obsolete_comments"
    
    # Find commented-out code (lines that look like code but are commented)
    echo "## Potentially Commented-Out Code" >> "$obsolete_comments"
    
    # Look for shell-style commented code
    find . \( -name "*.sh" -o -name "*.yaml" -o -name "*.yaml" \) -not -path "./.git/*" -not -path "./.taskmaster/*" | while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            local commented_code=$(grep -n "^[[:space:]]*#[[:space:]]*[a-zA-Z_].*[=\(\)\[\]\{\}]" "$file" 2>/dev/null || true)
            
            if [[ -n "$commented_code" ]]; then
                echo "### $file" >> "$obsolete_comments"
                while IFS= read -r line; do
                    echo "- Line $(echo "$line" | cut -d: -f1): \`$(echo "$line" | cut -d: -f2-)\`" >> "$obsolete_comments"
                done <<< "$commented_code"
                echo "" >> "$obsolete_comments"
            fi
        fi
    done
    
    # Look for TODO/FIXME/HACK comments that might be old
    echo "## TODO/FIXME/HACK Comments" >> "$obsolete_comments"
    
    find . -type f \( -name "*.sh" -o -name "*.yaml" -o -name "*.yaml" -o -name "*.md" -o -name "*.py" -o -name "*.go" \) \
        -not -path "./.git/*" -not -path "./.taskmaster/*" | while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            local todo_comments=$(grep -n -i "TODO\|FIXME\|HACK\|XXX" "$file" 2>/dev/null || true)
            
            if [[ -n "$todo_comments" ]]; then
                echo "### $file" >> "$obsolete_comments"
                while IFS= read -r line; do
                    echo "- Line $(echo "$line" | cut -d: -f1): \`$(echo "$line" | cut -d: -f2-)\`" >> "$obsolete_comments"
                done <<< "$todo_comments"
                echo "" >> "$obsolete_comments"
            fi
        fi
    done
    
    # Look for large comment blocks (might be excessive documentation)
    echo "## Large Comment Blocks" >> "$obsolete_comments"
    
    find . -name "*.sh" -not -path "./.git/*" -not -path "./.taskmaster/*" | while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            # Find consecutive comment lines (5 or more)
            local large_blocks=$(awk '/^[[:space:]]*#/ {count++; if(count==1) start=NR} !/^[[:space:]]*#/ {if(count>=5) print start":"(NR-1)":"count; count=0} END {if(count>=5) print start":"NR":"count}' "$file" 2>/dev/null || true)
            
            if [[ -n "$large_blocks" ]]; then
                echo "### $file" >> "$obsolete_comments"
                while IFS= read -r block; do
                    local start_line=$(echo "$block" | cut -d: -f1)
                    local end_line=$(echo "$block" | cut -d: -f2)
                    local line_count=$(echo "$block" | cut -d: -f3)
                    echo "- **Large comment block**: Lines $start_line-$end_line ($line_count lines)" >> "$obsolete_comments"
                done <<< "$large_blocks"
                echo "" >> "$obsolete_comments"
            fi
        fi
    done
    
    log_info "Comment analysis completed"
}

# Function to generate the final report
generate_report() {
    log_info "Generating comprehensive analysis report..."
    
    cat > "$REPORT_FILE" << 'EOF'
# Unused Code and Files Analysis Report

**Generated on:** $(date)
**Repository:** $(pwd)
**Git Branch:** $(git branch --show-current 2>/dev/null || echo "unknown")
**Git Commit:** $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

## Executive Summary

This report identifies potentially unused files, code elements, and comments in the repository. 
**IMPORTANT:** This is an automated analysis and may contain false positives. Manual review is recommended before taking any action.

---

EOF

    # Add unused files section
    echo "## 1. Potentially Unused Files" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    if [[ -f "$TEMP_DIR/final_unused_files.txt" && -s "$TEMP_DIR/final_unused_files.txt" ]]; then
        local file_count=$(wc -l < "$TEMP_DIR/final_unused_files.txt")
        echo "**Found $file_count potentially unused files:**" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        
        while IFS= read -r file; do
            echo "- \`$file\`" >> "$REPORT_FILE"
        done < "$TEMP_DIR/final_unused_files.txt"
    else
        echo "**No potentially unused files detected.**" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Add shell elements section
    echo "## 2. Shell Script Analysis" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    if [[ -f "$TEMP_DIR/unused_shell_elements.txt" ]]; then
        cat "$TEMP_DIR/unused_shell_elements.txt" >> "$REPORT_FILE"
    else
        echo "**No shell script analysis performed.**" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Add YAML elements section
    echo "## 3. YAML Configuration Analysis" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    if [[ -f "$TEMP_DIR/unused_yaml_elements.txt" ]]; then
        cat "$TEMP_DIR/unused_yaml_elements.txt" >> "$REPORT_FILE"
    else
        echo "**No YAML analysis performed.**" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Add comments section
    echo "## 4. Comment Analysis" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    if [[ -f "$TEMP_DIR/obsolete_comments.txt" ]]; then
        cat "$TEMP_DIR/obsolete_comments.txt" >> "$REPORT_FILE"
    else
        echo "**No comment analysis performed.**" >> "$REPORT_FILE"
    fi
    
    echo "" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Add recommendations
    cat >> "$REPORT_FILE" << 'EOF'
## 5. Recommendations

### Before Taking Action:
1. **Manual Review Required**: All findings should be manually reviewed before deletion
2. **Test Impact**: Consider the impact of removing files on build processes, deployment, or runtime
3. **Version Control**: Ensure you have committed your current work before making changes
4. **Backup**: Consider creating a backup branch before cleanup

### File Removal Guidelines:
- **Unused Files**: Verify files are truly unused by checking:
  - Build scripts and Makefiles
  - CI/CD pipelines
  - Documentation references
  - Dynamic imports or includes
- **Code Elements**: Verify functions/variables are not used via:
  - Reflection or dynamic calls
  - External scripts or tools
  - Future planned usage

### Comment Cleanup Guidelines:
- **Commented Code**: Remove if the code is truly obsolete
- **TODO Comments**: Either implement or remove if no longer relevant
- **Large Comment Blocks**: Review for relevance and accuracy

## 6. Analysis Methodology

This analysis used the following approaches:
- **File Usage**: Cross-referenced filenames across the codebase
- **Code Elements**: Pattern matching for function/variable definitions and usage
- **Comments**: Pattern matching for commented code and TODO items
- **Heuristic Approach**: Results may include false positives

**Tools Used:**
- `find` for file discovery
- `grep` for pattern matching
- `awk` for text processing
- Custom shell scripting for analysis logic

---

*Report generated by unused code analysis script*
*Manual verification recommended before taking any cleanup actions*
EOF

    # Replace placeholders with actual values
    sed -i "s/\$(date)/$(date)/" "$REPORT_FILE"
    sed -i "s|\$(pwd)|$(pwd)|" "$REPORT_FILE"
    sed -i "s/\$(git branch --show-current 2>\/dev\/null || echo \"unknown\")/$(git branch --show-current 2>/dev/null || echo "unknown")/" "$REPORT_FILE"
    sed -i "s/\$(git rev-parse --short HEAD 2>\/dev\/null || echo \"unknown\")/$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")/" "$REPORT_FILE"
    
    log_success "Report generated: $REPORT_FILE"
}

# Function to cleanup temporary files
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    log_success "Cleanup completed"
}

# Function to verify no modifications were made
verify_no_modifications() {
    log_info "Verifying no modifications were made to the repository..."
    
    if git diff --quiet && git diff --cached --quiet; then
        log_success "✅ Verification passed: No modifications detected"
        return 0
    else
        log_error "❌ Verification failed: Repository has been modified!"
        log_error "Please check 'git status' and 'git diff' for details"
        return 1
    fi
}

# Main execution function
main() {
    log_info "Starting unused code and files analysis..."
    
    # Setup
    setup_analysis
    
    # Run analysis steps
    analyze_unused_files
    analyze_unused_shell_elements
    analyze_unused_yaml_elements
    analyze_obsolete_comments
    
    # Generate report
    generate_report
    
    # Verify no modifications
    if verify_no_modifications; then
        log_success "Analysis completed successfully!"
        log_info "Report location: $REPORT_FILE"
        log_info "Review the report manually before taking any cleanup actions."
    else
        log_error "Analysis completed but repository was modified!"
        exit 1
    fi
    
    # Cleanup
    cleanup
}

# Handle script interruption
trap cleanup EXIT

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 