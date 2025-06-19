# Unused Code and Files Analysis Report

**Generated on:** K 18 juuni 2025 02:26:07 EEST
**Repository:** /home/andres/Projects/setup
**Git Branch:** main
**Git Commit:** 779b7c6

## Executive Summary

This report identifies potentially unused files, code elements, and comments in the repository. 
**IMPORTANT:** This is an automated analysis and may contain false positives. Manual review is recommended before taking any action.

---

## 1. Potentially Unused Files

**Found 19 potentially unused files:**

- `./gitops/infrastructure/charts/argo-cd-7.4.1.tgz`
- `./gitops/infrastructure/charts/cert-manager-v1.15.0.tgz`
- `./gitops/infrastructure/charts/ingress-nginx-4.11.2.tgz`
- `./gitops/infrastructure/charts/kube-prometheus-stack-61.9.0.tgz`
- `./gitops/infrastructure/charts/longhorn-1.7.1.tgz`
- `./gitops/infrastructure/charts/metallb-0.14.8.tgz`
- `./gitops/infrastructure/charts/sealed-secrets-2.15.2.tgz`
- `./infrastructure/roles/k3s-addons/security/sealed-secrets/templates/example-sealed-secret.yaml.j2`
- `./infrastructure/scripts/manage-sealed-secrets.sh`
- `./infrastructure/scripts/nuke-k3s.sh`
- `./infrastructure/scripts/validate-consolidation.sh`
- `./.pre-commit-config.yaml`
- `./.roo/rules-architect/architect-rules`
- `./.roo/rules-ask/ask-rules`
- `./.roo/rules-boomerang/boomerang-rules`
- `./.roo/rules-code/code-rules`
- `./.roo/rules-debug/debug-rules`
- `./.roo/rules-test/test-rules`
- `./scripts/analyze-unused-code.sh`

---

## 2. Shell Script Analysis

# Unused Shell Script Elements
## Analyzing: ./scripts/analyze-unused-code.sh
- **Potentially unused function**: `o` at line 22
- **Potentially unused function**: `n` at line 26
- **Potentially unused function**: `r` at line 30
- **Potentially unused function**: `s` at line 34
- **Potentially unused function**: `s` at line 39
- **Potentially unused function**: `s` at line 54
- **Potentially unused function**: `s` at line 123
- **Potentially unused function**: `s` at line 172
- **Potentially unused function**: `s` at line 212
- **Potentially unused function**: `t` at line 279
- **Potentially unused function**: `p` at line 417
- **Potentially unused function**: `s` at line 424
- **Potentially unused function**: `n` at line 438
- **Potentially unused variable**: `10:REPORT_DIR` at line 10
- **Potentially unused variable**: `11:REPORT_FILE` at line 11
- **Potentially unused variable**: `12:TEMP_DIR` at line 12
- **Potentially unused variable**: `15:RED` at line 15
- **Potentially unused variable**: `16:GREEN` at line 16
- **Potentially unused variable**: `17:YELLOW` at line 17
- **Potentially unused variable**: `18:BLUE` at line 18
- **Potentially unused variable**: `19:NC` at line 19
- **Potentially unused variable**: `79:            filename` at line 79
- **Potentially unused variable**: `80:            filename_no_ext` at line 80

## Analyzing: ./setup.sh
- **Potentially unused variable**: `5:  playbook` at line 5
- **Potentially unused variable**: `8:  playbook` at line 8

## Analyzing: ./infrastructure/scripts/validate-consolidation.sh
- **Potentially unused function**: `o` at line 15
- **Potentially unused function**: `s` at line 19
- **Potentially unused function**: `g` at line 23
- **Potentially unused function**: `r` at line 27
- **Potentially unused function**: `t` at line 37
- **Potentially unused function**: `e` at line 210
- **Potentially unused variable**: `8:RED` at line 8
- **Potentially unused variable**: `9:GREEN` at line 9
- **Potentially unused variable**: `10:YELLOW` at line 10
- **Potentially unused variable**: `11:BLUE` at line 11
- **Potentially unused variable**: `12:NC` at line 12
- **Potentially unused variable**: `32:TESTS_TOTAL` at line 32
- **Potentially unused variable**: `33:TESTS_PASSED` at line 33
- **Potentially unused variable**: `34:TESTS_FAILED` at line 34
- **Potentially unused variable**: `41:    TESTS_TOTAL` at line 41
- **Potentially unused variable**: `46:        TESTS_PASSED` at line 46
- **Potentially unused variable**: `50:        TESTS_FAILED` at line 50
- **Potentially unused variable**: `56:PROJECT_ROOT` at line 56
- **Potentially unused variable**: `187:    control_plane_count` at line 187
- **Potentially unused variable**: `188:    workers_count` at line 188
- **Potentially unused variable**: `261:    SUCCESS_RATE` at line 261
- **Potentially unused variable**: `263:    SUCCESS_RATE` at line 263

## Analyzing: ./infrastructure/scripts/manage-sealed-secrets.sh
- **Potentially unused function**: `o` at line 22
- **Potentially unused function**: `s` at line 26
- **Potentially unused function**: `g` at line 30
- **Potentially unused function**: `r` at line 34
- **Potentially unused function**: `s` at line 39
- **Potentially unused function**: `s` at line 44
- **Potentially unused function**: `y` at line 90
- **Potentially unused function**: `t` at line 107
- **Potentially unused function**: `t` at line 122
- **Potentially unused function**: `t` at line 198
- **Potentially unused function**: `t` at line 241
- **Potentially unused function**: `t` at line 272
- **Potentially unused function**: `s` at line 302
- **Potentially unused function**: `k` at line 342
- **Potentially unused function**: `t` at line 362
- **Potentially unused function**: `e` at line 381
- **Potentially unused function**: `n` at line 420
- **Potentially unused variable**: `8:SCRIPT_DIR` at line 8
- **Potentially unused variable**: `9:PROJECT_ROOT` at line 9
- **Potentially unused variable**: `10:KUBECONFIG` at line 10
- **Potentially unused variable**: `11:SEALED_SECRETS_NS` at line 11
- **Potentially unused variable**: `12:GITOPS_SECRETS_DIR` at line 12
- **Potentially unused variable**: `15:RED` at line 15
- **Potentially unused variable**: `16:GREEN` at line 16
- **Potentially unused variable**: `17:YELLOW` at line 17
- **Potentially unused variable**: `18:BLUE` at line 18
- **Potentially unused variable**: `19:NC` at line 19

## Analyzing: ./infrastructure/scripts/nuke-k3s.sh
- **Potentially unused variable**: `12:HOSTNAME_ARG` at line 12
- **Potentially unused variable**: `15:REBOOT_PROMPT` at line 15
- **Potentially unused variable**: `17:  REBOOT_PROMPT` at line 17
- **Potentially unused variable**: `19:  REBOOT_PROMPT` at line 19

## Analyzing: ./infrastructure/roles/k3s-addons/networking/metallb/files/validate-metallb.sh
- **Potentially unused function**: `n` at line 68
- **Potentially unused variable**: `23:CONTROLLER_READY` at line 23
- **Potentially unused variable**: `27:SPEAKER_READY` at line 27
- **Potentially unused variable**: `33:    POOL_ADDRESSES` at line 33
- **Potentially unused variable**: `60:    EXTERNAL_IP` at line 60
- **Potentially unused variable**: `67:            IP_OCTET` at line 67

## Analyzing: ./infrastructure/roles/k3s-addons/networking/ingress-nginx/files/validate-ingress-nginx.sh
- **Potentially unused function**: `n` at line 68
- **Potentially unused variable**: `23:CONTROLLER_PODS` at line 23
- **Potentially unused variable**: `29:RUNNING_CONTROLLERS` at line 29
- **Potentially unused variable**: `30:TOTAL_CONTROLLERS` at line 30
- **Potentially unused variable**: `34:DAEMONSET_INFO` at line 34
- **Potentially unused variable**: `37:    DESIRED` at line 37
- **Potentially unused variable**: `38:    READY` at line 38
- **Potentially unused variable**: `50:HOST_NETWORK` at line 50
- **Potentially unused variable**: `60:    EXTERNAL_IP` at line 60
- **Potentially unused variable**: `67:            IP_OCTET` at line 67
- **Potentially unused variable**: `89:DEFAULT_CLASS` at line 89
- **Potentially unused variable**: `103:    WAF_RESPONSE` at line 103
- **Potentially unused variable**: `119:    TEST_PODS` at line 119
- **Potentially unused variable**: `135:MODSEC_CONFIG` at line 135
- **Potentially unused variable**: `143:OWASP_CONFIG` at line 143

## Analyzing: ./infrastructure/roles/k3s-addons/storage/longhorn/files/validate-longhorn.sh
- **Potentially unused variable**: `22:MANAGER_READY` at line 22
- **Potentially unused variable**: `26:UI_READY` at line 26
- **Potentially unused variable**: `30:ENGINE_READY` at line 30
- **Potentially unused variable**: `34:CSI_DRIVER_READY` at line 34
- **Potentially unused variable**: `35:CSI_PROVISIONER_READY` at line 35
- **Potentially unused variable**: `36:CSI_RESIZER_READY` at line 36
- **Potentially unused variable**: `37:CSI_SNAPSHOTTER_READY` at line 37
- **Potentially unused variable**: `52:    IS_DEFAULT` at line 52
- **Potentially unused variable**: `60:    REPLICA_COUNT` at line 60
- **Potentially unused variable**: `70:NODE_COUNT` at line 70
- **Potentially unused variable**: `84:    NVME_DISKS` at line 84
- **Potentially unused variable**: `123:    PVC_STATUS` at line 123
- **Potentially unused variable**: `137:PV_NAME` at line 137
- **Potentially unused variable**: `139:    REPLICA_COUNT` at line 139
- **Potentially unused variable**: `147:    REPLICA_STATUS` at line 147
- **Potentially unused variable**: `164:UI_SERVICE` at line 164
- **Potentially unused variable**: `166:    NODE_IP` at line 166
- **Potentially unused variable**: `175:BACKUP_TARGET` at line 175


---

## 3. YAML Configuration Analysis

# Unused YAML Elements
## Analyzing: ./gitops/secrets/dev/example-app-secrets.yaml

## Analyzing: ./gitops/argocd/infrastructure-appset.yaml

## Analyzing: ./gitops/argocd/applications-appset.yaml

## Analyzing: ./gitops/environments/staging/values.yaml

## Analyzing: ./gitops/environments/dev/values.yaml

## Analyzing: ./gitops/environments/production/values.yaml

## Analyzing: ./gitops/infrastructure/Chart.yaml

## Analyzing: ./gitops/infrastructure/values.yaml

## Analyzing: ./gitops/applications/example-app/Chart.yaml

## Analyzing: ./.github/workflows/ci.yml

## Analyzing: ./.github/workflows/integration-tests.yml

## Analyzing: ./.pre-commit-config.yaml

## Analyzing: ./infrastructure/playbooks/networking.yml

## Analyzing: ./infrastructure/playbooks/site.yml

## Analyzing: ./infrastructure/playbooks/security.yml

## Analyzing: ./infrastructure/playbooks/specialized.yml

## Analyzing: ./infrastructure/playbooks/observability.yml

## Analyzing: ./infrastructure/playbooks/storage.yml

## Analyzing: ./infrastructure/playbooks/maintenance.yml

## Analyzing: ./infrastructure/playbooks/k3s_cluster.yml

## Analyzing: ./infrastructure/roles/core/base/tasks/main.yml

## Analyzing: ./infrastructure/roles/platform/ux/tasks/main.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_lens.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_docker.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_ai_tools.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_cursor.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_jetbrains_toolbox.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_git.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/main.yml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_kubectl.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_chrome.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_node.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_go.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_python3.yaml

## Analyzing: ./infrastructure/roles/platform/tools/tasks/install_helm.yaml

## Analyzing: ./infrastructure/roles/platform/gpu/tasks/main.yaml

## Analyzing: ./infrastructure/roles/data-services/redis/tasks/main.yaml

## Analyzing: ./infrastructure/roles/data-services/kafka/tasks/main.yaml

## Analyzing: ./infrastructure/roles/data-services/postgres/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/gitops/argocd/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/gitops/argocd/defaults/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/networking/external-dns/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/networking/external-dns/defaults/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/networking/metallb/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/networking/ha-proxy/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/networking/ingress-nginx/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/cluster/tasks/main.yml

## Analyzing: ./infrastructure/roles/k3s-addons/cluster/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/storage/longhorn/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/security/tls/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/security/tls/defaults/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/security/cert-manager/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/security/cert-manager/defaults/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/security/sealed-secrets/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/security/sealed-secrets/defaults/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/observability/monitoring/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/observability/monitoring/defaults/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/observability/logging/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/observability/logging/defaults/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/high-availability/ha-testing/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/high-availability/etcd-backup/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/high-availability/etcd-backup/defaults/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/high-availability/chaos-testing/tasks/main.yaml

## Analyzing: ./infrastructure/roles/k3s-addons/high-availability/chaos-testing/defaults/main.yaml

## Analyzing: ./infrastructure/roles/applications/media/tasks/main.yml

## Analyzing: ./infrastructure/inventory/staging/group_vars/all.yml

## Analyzing: ./infrastructure/inventory/staging/hosts.yml

## Analyzing: ./infrastructure/inventory/dev/group_vars/ingress_nginx.yml

## Analyzing: ./infrastructure/inventory/dev/group_vars/all.yml

## Analyzing: ./infrastructure/inventory/dev/group_vars/control_plane.yml

## Analyzing: ./infrastructure/inventory/dev/group_vars/workers.yml

## Analyzing: ./infrastructure/inventory/dev/group_vars/metallb.yml

## Analyzing: ./infrastructure/inventory/dev/hosts.yml

## Analyzing: ./infrastructure/inventory/production/group_vars/ingress_nginx.yml

## Analyzing: ./infrastructure/inventory/production/group_vars/all.yml

## Analyzing: ./infrastructure/inventory/production/group_vars/control_plane.yml

## Analyzing: ./infrastructure/inventory/production/group_vars/workers.yml

## Analyzing: ./infrastructure/inventory/production/group_vars/metallb.yml

## Analyzing: ./infrastructure/inventory/production/hosts.yml

## Analyzing: ./infrastructure/legacy/deploy_metallb.yaml

## Analyzing: ./infrastructure/legacy/deploy_haproxy.yaml

## Analyzing: ./infrastructure/legacy/deploy_ingress_nginx.yaml


---

## 4. Comment Analysis

# Potentially Obsolete Comments
## Potentially Commented-Out Code
## TODO/FIXME/HACK Comments
### ./scripts/analyze-unused-code.sh
- Line 236: `    # Look for TODO/FIXME/HACK comments that might be old`
- Line 237: `    echo "## TODO/FIXME/HACK Comments" >> "$obsolete_comments"`
- Line 242: `            local todo_comments=$(grep -n -i "TODO\|FIXME\|HACK\|XXX" "$file" 2>/dev/null || true)`
- Line 244: `            if [[ -n "$todo_comments" ]]; then`
- Line 248: `                done <<< "$todo_comments"`
- Line 384: `- **TODO Comments**: Either implement or remove if no longer relevant`
- Line 392: `- **Comments**: Pattern matching for commented code and TODO items`

## Large Comment Blocks

---

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
