# YAML File Extension Standardization Plan

## Analysis Results

**Current State:**
- `.yaml` files: 54 files
- `.yml` files: 28 files  
- Total YAML files: 82 files

## Chosen Standard

**Decision: `.yaml` extension**

**Rationale:**
1. **Prevalence**: `.yaml` is used by 54 files (66%) vs `.yml` used by 28 files (34%)
2. **Industry Standard**: `.yaml` is the full, official extension
3. **GitOps Consistency**: Most GitOps manifests already use `.yaml`
4. **Kubernetes Ecosystem**: Kubernetes manifests typically use `.yaml`

## Files to Rename (28 total)

The following files will be renamed from `.yml` to `.yaml`:

### GitHub Workflows (2 files)
- `./.github/workflows/ci.yml` → `./.github/workflows/ci.yaml`
- `./.github/workflows/integration-tests.yml` → `./.github/workflows/integration-tests.yaml`

### Ansible Inventory Files (16 files)
- `./infrastructure/inventory/dev/group_vars/all.yml` → `./infrastructure/inventory/dev/group_vars/all.yaml`
- `./infrastructure/inventory/dev/group_vars/control_plane.yml` → `./infrastructure/inventory/dev/group_vars/control_plane.yaml`
- `./infrastructure/inventory/dev/group_vars/ingress_nginx.yml` → `./infrastructure/inventory/dev/group_vars/ingress_nginx.yaml`
- `./infrastructure/inventory/dev/group_vars/metallb.yml` → `./infrastructure/inventory/dev/group_vars/metallb.yaml`
- `./infrastructure/inventory/dev/group_vars/workers.yml` → `./infrastructure/inventory/dev/group_vars/workers.yaml`
- `./infrastructure/inventory/dev/hosts.yml` → `./infrastructure/inventory/dev/hosts.yaml`
- `./infrastructure/inventory/production/group_vars/all.yml` → `./infrastructure/inventory/production/group_vars/all.yaml`
- `./infrastructure/inventory/production/group_vars/control_plane.yml` → `./infrastructure/inventory/production/group_vars/control_plane.yaml`
- `./infrastructure/inventory/production/group_vars/ingress_nginx.yml` → `./infrastructure/inventory/production/group_vars/ingress_nginx.yaml`
- `./infrastructure/inventory/production/group_vars/metallb.yml` → `./infrastructure/inventory/production/group_vars/metallb.yaml`
- `./infrastructure/inventory/production/group_vars/workers.yml` → `./infrastructure/inventory/production/group_vars/workers.yaml`
- `./infrastructure/inventory/production/hosts.yml` → `./infrastructure/inventory/production/hosts.yaml`
- `./infrastructure/inventory/staging/group_vars/all.yml` → `./infrastructure/inventory/staging/group_vars/all.yaml`
- `./infrastructure/inventory/staging/hosts.yml` → `./infrastructure/inventory/staging/hosts.yaml`

### Ansible Playbooks (8 files)
- `./infrastructure/playbooks/k3s_cluster.yml` → `./infrastructure/playbooks/k3s_cluster.yaml`
- `./infrastructure/playbooks/maintenance.yml` → `./infrastructure/playbooks/maintenance.yaml`
- `./infrastructure/playbooks/networking.yml` → `./infrastructure/playbooks/networking.yaml`
- `./infrastructure/playbooks/observability.yml` → `./infrastructure/playbooks/observability.yaml`
- `./infrastructure/playbooks/security.yml` → `./infrastructure/playbooks/security.yaml`
- `./infrastructure/playbooks/site.yml` → `./infrastructure/playbooks/site.yaml`
- `./infrastructure/playbooks/specialized.yml` → `./infrastructure/playbooks/specialized.yaml`
- `./infrastructure/playbooks/storage.yml` → `./infrastructure/playbooks/storage.yaml`

### Ansible Role Tasks (4 files)
- `./infrastructure/roles/applications/media/tasks/main.yml` → `./infrastructure/roles/applications/media/tasks/main.yaml`
- `./infrastructure/roles/core/base/tasks/main.yml` → `./infrastructure/roles/core/base/tasks/main.yaml`
- `./infrastructure/roles/k3s-addons/cluster/tasks/main.yml` → `./infrastructure/roles/k3s-addons/cluster/tasks/main.yaml`
- `./infrastructure/roles/platform/tools/tasks/main.yml` → `./infrastructure/roles/platform/tools/tasks/main.yaml`

## Next Steps

1. **Locate References**: Search codebase for references to these files
2. **Rename Files**: Use `git mv` to rename files maintaining Git history
3. **Update References**: Update all references in code, documentation, and configs
4. **Test Changes**: Verify functionality still works after changes
5. **Clean Up**: Remove this planning file and temporary files

## Impact Areas to Check

- Ansible playbook imports and includes
- GitHub Actions workflow references  
- Documentation links
- CI/CD pipeline configurations
- Any scripts that reference these files
- README files and setup instructions 