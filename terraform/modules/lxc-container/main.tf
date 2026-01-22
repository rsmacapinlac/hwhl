# ============================================
# LXC Container Module - Main Resource
# ============================================

resource "proxmox_virtual_environment_container" "container" {
  vm_id       = var.vmid
  node_name   = var.node
  description = "Managed by Terraform"

  tags = var.tags

  # Start container after creation
  started = var.start_on_create

  # Startup order and delay
  startup {
    order = var.startup_order
    up_delay = 30
    down_delay = 30
  }

  # Security settings
  unprivileged = var.unprivileged

  # Enable nesting for Docker support (only for unprivileged containers via API)
  # Note: mount features must be set via SSH due to Proxmox API limitations
  dynamic "features" {
    for_each = var.unprivileged ? [1] : []
    content {
      nesting = var.nesting
    }
  }

  # Operating system template
  operating_system {
    template_file_id = var.template
    type             = "debian"
  }

  # Root disk
  disk {
    datastore_id = var.datastore
    size         = var.disk_size
  }

  # CPU configuration
  cpu {
    cores = var.cores
  }

  # Memory configuration
  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  # Network configuration
  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  # Note: Bind mount points cannot be created via API tokens (Proxmox limitation)
  # They must be added via SSH after container creation (see terraform_data.configure_mount_points below)
  # Ignore changes to attributes that:
  # - Are managed externally (mount_point)
  # - Force replacement on imported containers (unprivileged, initialization, network_interface)
  lifecycle {
    ignore_changes = [
      mount_point,
      unprivileged,
      initialization,
      network_interface,
      features,
      operating_system,
    ]
  }

  # Initialization - runs on first boot
  initialization {
    hostname = var.name

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      domain  = var.dns_domain != "" ? var.dns_domain : null
      servers = split(",", replace(var.nameserver, " ", ""))
    }

    user_account {
      password = var.root_password
      keys     = [var.ssh_public_key]
    }
  }
}

# Enable nesting for privileged containers via SSH (API doesn't allow this)
resource "terraform_data" "enable_nesting" {
  count = !var.unprivileged && var.nesting && var.proxmox_host != "" ? 1 : 0

  depends_on = [proxmox_virtual_environment_container.container]

  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.proxmox_host} 'pct set ${var.vmid} -features nesting=1 && pct reboot ${var.vmid}'"
  }
}

# Enable mount features for unprivileged containers via SSH (API doesn't allow this)
resource "terraform_data" "enable_mount_features" {
  count = var.unprivileged && var.proxmox_host != "" ? 1 : 0

  depends_on = [proxmox_virtual_environment_container.container]

  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no root@${var.proxmox_host} 'pct set ${var.vmid} -features nesting=1,mount=nfs\\;cifs && pct reboot ${var.vmid}'"
  }
}

# Configure bind mount points via SSH (required because API tokens can't create bind mounts)
resource "terraform_data" "configure_mount_points" {
  count = var.proxmox_host != "" ? 1 : 0

  depends_on = [proxmox_virtual_environment_container.container]

  # Re-run if mount points change - store as JSON string for change detection
  # The mount_points list is encoded to detect changes in the list contents
  input = jsonencode(var.mount_points)

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for container to be ready
      sleep 5

      # Stop container before modifying mount points (required by Proxmox)
      ssh -o StrictHostKeyChecking=no root@${var.proxmox_host} "pct stop ${var.vmid}" || true
      sleep 2

      # Remove all existing mount points first (to handle removals and changes)
      # Get current mount points and remove them
      EXISTING_MPS=$(ssh -o StrictHostKeyChecking=no root@${var.proxmox_host} "pct config ${var.vmid} 2>/dev/null | grep -E '^mp[0-9]+:' | cut -d: -f1" || echo "")
      for mp in $EXISTING_MPS; do
        ssh -o StrictHostKeyChecking=no root@${var.proxmox_host} "pct set ${var.vmid} -delete $mp" || true
      done

      # Add each mount point from configuration via pct set command
%{ for idx, mount in var.mount_points ~}
      ssh -o StrictHostKeyChecking=no root@${var.proxmox_host} "pct set ${var.vmid} -mp${idx} ${mount.host_path},mp=${mount.container_path}" || true
%{ endfor ~}

      # Start container after mount points are configured
      ssh -o StrictHostKeyChecking=no root@${var.proxmox_host} "pct start ${var.vmid}" || true
    EOT
  }

  # Remove mount points when resource is destroyed (e.g., when mount_points becomes empty)
  # Note: We can't access var.* in destroy provisioners, so we store needed values separately
  # For now, we'll rely on the main provisioner handling empty mount_points lists
  # If the resource is destroyed entirely, mount points will remain (this is acceptable
  # as the container itself would typically be destroyed too)
}

# Note: Ansible user creation is handled by Ansible's common role
# After Terraform creates the container, run Ansible to configure it:
#   ansible-playbook site.yml --limit <container-group>
