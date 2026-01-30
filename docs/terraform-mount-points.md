# Terraform Mount Points for LXC Containers

## Overview

This document explains how to bind mount NFS shares (or any host directories) into LXC containers created by Terraform. This allows containers to access NFS shares that were mounted on the Proxmox host via Ansible.

## How It Works

1. **Ansible** mounts NFS shares on the Proxmox host (e.g., `/mnt/ContainerBackups`)
2. **Terraform** creates LXC containers with bind mounts that map those host paths into the containers
3. Containers can access the NFS shares as if they were local directories

## Configuration

### Step 1: Mount NFS Shares on Proxmox Host (Ansible)

Configure NFS shares in `homelab_config/ansible/group_vars/all.yml`:

```yaml
proxmox_nfs_shares:
  - source: "10.1.0.95:/nfs/ContainerBackups"
    destination: "/mnt/ContainerBackups"
    options: "defaults,noatime"
```

Run the Ansible playbook to mount the shares:
```bash
ansible-playbook proxmox-setup.yml
```

### Step 2: Configure Mount Points in Terraform

Edit `terraform/terraform.tfvars` (or the template in `ansible/roles/proxmox/templates/terraform.tfvars.j2`) to add mount points to your containers:

```hcl
edge_containers = {
  "edge-01" = {
    vmid       = 400
    node       = "pve-01"
    ip_address = "10.1.0.20/24"
    gateway    = "10.1.0.1"
    nameserver = "10.1.0.10"
    memory     = 4096
    swap       = 4096
    cores      = 2
    disk_size  = 64
    mount_points = [
      {
        host_path      = "/mnt/ContainerBackups"  # Path on Proxmox host
        container_path  = "/mnt/backups"           # Path inside container
      }
    ]
  }
}
```

### Step 3: Apply Terraform Configuration

```bash
cd terraform
terraform plan
terraform apply
```

## Mount Point Configuration

Each mount point requires two paths:

- **`host_path`**: The path on the Proxmox host where the NFS share is mounted (from `proxmox_nfs_shares` in Ansible)
- **`container_path`**: The path inside the container where the share will be accessible

### Example: Multiple Mount Points

```hcl
mount_points = [
  {
    host_path      = "/mnt/ContainerBackups"
    container_path  = "/mnt/backups"
  },
  {
    host_path      = "/mnt/vm-storage"
    container_path  = "/mnt/storage"
  }
]
```

## Important Notes

### 1. Path Must Exist on Host

The `host_path` must exist and be mounted on the Proxmox host **before** Terraform creates the container. Ensure:
- Ansible has mounted the NFS share
- The mount point directory exists on the host

### 2. Unprivileged Containers

If using unprivileged containers (default), be aware of UID/GID mapping:
- Host UIDs are mapped to container UIDs (+100000 by default)
- Ensure file permissions on the NFS share are appropriate
- Consider using `ansible` user (UID 1001) or adjusting permissions

### 3. Container Restart

Mount points are configured when the container is created. To add mount points to existing containers:
- Update `terraform.tfvars`
- Run `terraform apply`
- The container will be updated with the new mount points

### 4. Backups

Bind-mounted directories are **not included** in Proxmox backups (`vzdump`). The NFS share itself should be backed up separately.

## Troubleshooting

### Mount Point Not Visible in Container

1. **Verify host mount exists:**
   ```bash
   ssh root@<proxmox-host> "mount | grep /mnt/ContainerBackups"
   ```

2. **Check container configuration:**
   ```bash
   ssh root@<proxmox-host> "cat /etc/pve/lxc/<VMID>.conf | grep mp"
   ```

3. **Verify mount in container:**
   ```bash
   ssh root@<container-ip> "mount | grep /mnt/backups"
   ```

### Permission Issues

If files appear as `nobody` or are inaccessible:
- Check UID/GID mapping for unprivileged containers
- Adjust file ownership on the NFS share
- Consider using privileged containers (not recommended for security)

## Integration with Ansible

The Terraform template (`terraform.tfvars.j2`) can reference Ansible variables, but mount points are typically configured manually in `terraform.tfvars` after the file is generated. This allows flexibility in choosing which containers get which mounts.

For automated configuration, you could extend the Ansible template to include mount points based on container type or tags, but manual configuration is recommended for clarity.

## Example Use Cases

1. **Backup Storage**: Mount backup NFS share into containers that need backup access
2. **Shared Media**: Mount media library NFS share into media server containers
3. **Configuration Files**: Mount shared config directory into multiple containers
4. **Log Storage**: Mount centralized log storage into containers
