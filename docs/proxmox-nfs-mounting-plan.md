# Proxmox NFS Mounting Implementation Plan

## Overview
This document outlines the plan for implementing NFS share mounting on Proxmox nodes, following the existing patterns used for Docker container shares.

## Design Goals
1. **Consistency**: Follow the same configuration pattern as the `shares` role used for Docker containers
2. **Flexibility**: Support multiple NFS shares per Proxmox node
3. **Configuration-driven**: Use inventory/group_vars for configuration (similar to Docker containers)
4. **Idempotency**: Safe to run multiple times
5. **Optional**: Should work even if no shares are configured

## Architecture Decision

### Option 1: Extend Existing Proxmox Role (Recommended)
**Pros:**
- Keeps Proxmox-related tasks together
- Single role to manage for Proxmox setup
- Natural extension of `proxmox-setup.yml` workflow

**Cons:**
- Mixes initial setup with ongoing configuration
- Could make the role larger

**Decision: Extend the proxmox role** - This keeps all Proxmox configuration in one place and follows the pattern where `proxmox-setup.yml` handles initial setup.

### Option 2: Separate Role
**Pros:**
- Clear separation of concerns
- Could be reused for other hypervisors

**Cons:**
- Additional role to maintain
- Less cohesive with Proxmox setup

## Configuration Structure

### Pattern: List-based Configuration (Following `shares` Role Pattern)

```yaml
# group_vars/all.yml or host_vars/<hostname>.yml
proxmox_nfs_shares:
  - name: container-backups
    source: "daikichi.local:/nfs/ContainerBackups"
    destination: "/mnt/ContainerBackups"
    options: "defaults,noatime"
  - name: vm-storage
    source: "nas.local:/export/vm-storage"
    destination: "/mnt/vm-storage"
    options: "defaults,noatime,rsize=8192,wsize=8192"
```

### Alternative: Dictionary-based Configuration (For Named Access)

```yaml
# If you need named access like nextcloud does
proxmox_nfs_shares:
  container-backups:
    source: "daikichi.local:/nfs/ContainerBackups"
    destination: "/mnt/ContainerBackups"
    options: "defaults,noatime"
  vm-storage:
    source: "nas.local:/export/vm-storage"
    destination: "/mnt/vm-storage"
    options: "defaults,noatime,rsize=8192,wsize=8192"
```

**Recommendation: Use list-based** - Simpler, consistent with existing `shares` role, and easier to iterate.

## Implementation Structure

### File Organization
```
ansible/roles/proxmox/
├── defaults/main.yml          # Add proxmox_nfs_shares: []
├── tasks/
│   ├── main.yml               # Include nfs-mounts.yml
│   └── nfs-mounts.yml         # New file for NFS mounting tasks
└── ...
```

### Task Structure (Following `shares` Role Pattern)

```yaml
# tasks/nfs-mounts.yml
---
# ============================================
# Proxmox NFS Share Mounting
# ============================================
# Mounts NFS shares configured in proxmox_nfs_shares variable
# Configuration should be in group_vars/all.yml or host_vars/<hostname>.yml
# ============================================

- name: Install NFS client packages
  apt:
    name:
      - nfs-common
      - nfs4-acl-tools
    state: present
    update_cache: yes
  when: proxmox_nfs_shares | length > 0

- name: Create mountpoint directories
  file:
    path: "{{ item.destination }}"
    state: directory
    mode: '0755'
  loop: "{{ proxmox_nfs_shares }}"
  when: proxmox_nfs_shares | length > 0

- name: Mount NFS shares
  ansible.posix.mount:
    fstype: nfs
    src: "{{ item.source }}"
    path: "{{ item.destination }}"
    opts: "{{ item.options | default('defaults') }}"
    state: mounted
  loop: "{{ proxmox_nfs_shares }}"
  when: proxmox_nfs_shares | length > 0
```

### Integration with proxmox-setup.yml

The NFS mounting will be included in the proxmox role's main.yml, so it runs automatically when `proxmox-setup.yml` is executed. This means:
- Initial Proxmox setup includes NFS mounting
- Can be run independently via the proxmox role
- Idempotent - safe to run multiple times

## Configuration Examples

### Example 1: Single Share (Simple)
```yaml
# group_vars/all.yml
proxmox_nfs_shares:
  - source: "nas.local:/export/backups"
    destination: "/mnt/backups"
    options: "defaults"
```

### Example 2: Multiple Shares (Production)
```yaml
# group_vars/all.yml
proxmox_nfs_shares:
  - name: container-backups
    source: "daikichi.local:/nfs/ContainerBackups"
    destination: "/mnt/ContainerBackups"
    options: "defaults,noatime"
  - name: vm-templates
    source: "nas.local:/export/vm-templates"
    destination: "/mnt/vm-templates"
    options: "defaults,noatime,rsize=8192,wsize=8192"
  - name: iso-storage
    source: "nas.local:/export/iso"
    destination: "/mnt/iso"
    options: "defaults,noatime,soft,timeo=30"
```

### Example 3: Host-Specific Configuration
```yaml
# host_vars/pve-01.yml
proxmox_nfs_shares:
  - source: "nas.local:/export/pve-01-storage"
    destination: "/mnt/storage"
    options: "defaults,noatime"
```

## Default Options

The implementation should provide sensible defaults:
- `options: "defaults"` if not specified
- Common NFS options to consider:
  - `noatime` - Don't update access times (better performance)
  - `rsize=8192,wsize=8192` - Larger read/write sizes for better performance
  - `soft` - Allow I/O errors to fail gracefully
  - `timeo=30` - Timeout in tenths of seconds

## Error Handling

1. **Missing NFS server**: The mount will fail, but Ansible will report the error clearly
2. **Already mounted**: The `ansible.posix.mount` module handles this idempotently
3. **Permission issues**: Should be handled at the NFS server level
4. **Network issues**: Will fail gracefully with clear error messages

## Testing Strategy

1. **Empty configuration**: Should skip all tasks (when: proxmox_nfs_shares | length > 0)
2. **Single share**: Mount one share successfully
3. **Multiple shares**: Mount all shares correctly
4. **Idempotency**: Running twice should not cause errors
5. **Invalid source**: Should fail with clear error message

## Comparison with Docker Container Shares

| Aspect | Docker Containers (shares role) | Proxmox Nodes (proposed) |
|--------|--------------------------------|--------------------------|
| Configuration | `shares: []` in group_vars | `proxmox_nfs_shares: []` in group_vars |
| File system types | NFS, SMB/CIFS | NFS (primary), could extend to SMB |
| Mount location | `/data/*` or `/mnt/*` | `/mnt/*` (standard for Proxmox) |
| Dependencies | cifs-utils, nfs-common | nfs-common, nfs4-acl-tools |
| Role structure | Separate `shares` role | Part of `proxmox` role |
| Usage | Included in service roles | Included in proxmox-setup.yml |

## Future Enhancements

1. **SMB/CIFS support**: Add support for Windows shares (similar to shares role)
2. **Auto-discovery**: Could add Proxmox storage configuration via API
3. **Monitoring**: Add checks to verify mounts are healthy
4. **Backup integration**: Automatically configure Proxmox backup storage

## Implementation Checklist

- [ ] Create `tasks/nfs-mounts.yml` in proxmox role
- [ ] Add `proxmox_nfs_shares: []` to `defaults/main.yml`
- [ ] Include nfs-mounts.yml in `tasks/main.yml`
- [ ] Add configuration examples to `group_vars/all.yml`
- [ ] Test with empty configuration
- [ ] Test with single share
- [ ] Test with multiple shares
- [ ] Verify idempotency
- [ ] Update documentation

## Questions to Resolve

1. **Mount location convention**: Use `/mnt/` (standard) or `/storage/` (Proxmox convention)?
   - **Recommendation**: `/mnt/` - more standard, easier to remember

2. **Include in proxmox-setup.yml or separate playbook?**
   - **Recommendation**: Include in proxmox role, runs with proxmox-setup.yml

3. **Support for SMB/CIFS?**
   - **Recommendation**: Start with NFS only, add SMB later if needed

4. **Auto-configure Proxmox storage?**
   - **Recommendation**: Manual configuration for now, auto-config could be future enhancement
